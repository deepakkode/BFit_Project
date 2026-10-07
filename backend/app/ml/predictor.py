from pathlib import Path
from typing import Protocol

import joblib
import numpy as np

from app.core.config import settings
from app.ml.deepconv_lstm import DeepConvLSTM
from app.schemas.contracts import SensorSample

FEATURE_COUNT = 21


class ModelUnavailableError(RuntimeError):
    pass


class ActivityPredictor(Protocol):
    model_name: str
    version: str | None

    def predict(self, samples: list[SensorSample]) -> tuple[str, float]: ...


def extract_features(samples: list[SensorSample]) -> np.ndarray:
    axes = np.asarray([[sample.acc_x, sample.acc_y, sample.acc_z] for sample in samples], dtype=np.float64)
    magnitude = np.linalg.norm(axes, axis=1)
    features = [*axes.mean(axis=0), *axes.std(axis=0), *axes.min(axis=0), *axes.max(axis=0), *np.ptp(axes, axis=0)]
    features.extend([magnitude.mean(), magnitude.std(), magnitude.min(), magnitude.max(), np.ptp(magnitude), np.sqrt(np.mean(magnitude**2))])
    return np.asarray(features, dtype=np.float64).reshape(1, FEATURE_COUNT)


class RandomForestPredictor:
    model_name = "random_forest"

    def __init__(self, artifact_path: str | None = None):
        self.artifact_path = Path(artifact_path or settings.ml_artifact_path).resolve()
        self._bundle: dict | None = None

    def load(self) -> None:
        if not self.artifact_path.is_file():
            raise ModelUnavailableError(f"Model artifact not found: {self.artifact_path}")
        bundle = joblib.load(self.artifact_path)
        if not isinstance(bundle, dict) or "model" not in bundle:
            raise ModelUnavailableError("Model artifact has an unsupported format")
        self._bundle = bundle

    @property
    def version(self) -> str | None:
        return self._bundle.get("version") if self._bundle else None

    def predict(self, samples: list[SensorSample]) -> tuple[str, float]:
        if self._bundle is None:
            self.load()
        assert self._bundle is not None
        model = self._bundle["model"]
        features = extract_features(samples)
        prediction = str(model.predict(features)[0])
        probabilities = model.predict_proba(features)[0]
        confidence = float(np.max(probabilities))
        return prediction, confidence


class DeepConvLSTMPredictor:
    model_name = "deepconv_lstm"

    def __init__(self, artifact_path: str | None = None):
        self.artifact_path = Path(artifact_path or settings.deepconv_lstm_artifact_path).resolve()
        self._bundle: dict | None = None
        self._model = None
        self._torch = None

    def load(self) -> None:
        if not self.artifact_path.is_file():
            raise ModelUnavailableError(f"Model artifact not found: {self.artifact_path}")
        try:
            import torch

            bundle = torch.load(self.artifact_path, map_location="cpu", weights_only=False)
            if not isinstance(bundle, dict) or "model_state_dict" not in bundle:
                raise ModelUnavailableError("DeepConvLSTM artifact has an unsupported format")
            model = DeepConvLSTM(**bundle.get("model_config", {}))
            model.load_state_dict(bundle["model_state_dict"])
            model.eval()
        except ModelUnavailableError:
            raise
        except (ImportError, OSError, RuntimeError, ValueError) as exc:
            raise ModelUnavailableError(f"DeepConvLSTM artifact could not be loaded: {exc}") from exc
        self._bundle = bundle
        self._model = model
        self._torch = torch

    @property
    def version(self) -> str | None:
        return str(self._bundle.get("version")) if self._bundle else None

    def predict(self, samples: list[SensorSample]) -> tuple[str, float]:
        if self._bundle is None:
            self.load()
        assert self._bundle is not None and self._model is not None and self._torch is not None
        class_labels = self._bundle["class_labels"]
        axis_mean = np.asarray(self._bundle["axis_mean"], dtype=np.float32)
        axis_std = np.asarray(self._bundle["axis_std"], dtype=np.float32)
        axes = np.asarray([[sample.acc_x, sample.acc_y, sample.acc_z] for sample in samples], dtype=np.float32)
        normalized = (axes - axis_mean) / axis_std
        batch = self._torch.from_numpy(normalized[None, :, :])
        with self._torch.inference_mode():
            probabilities = self._torch.softmax(self._model(batch), dim=1)[0]
        index = int(probabilities.argmax().item())
        return str(class_labels[index]), float(probabilities[index].item())


def create_activity_predictor() -> ActivityPredictor:
    model_name = settings.activity_model.strip().lower()
    if model_name == "auto":
        candidate_path = Path(settings.deepconv_lstm_artifact_path).resolve()
        model_name = "deepconv_lstm" if candidate_path.is_file() else "random_forest"
    if model_name == "random_forest":
        return RandomForestPredictor()
    if model_name == "deepconv_lstm":
        return DeepConvLSTMPredictor()
    raise ModelUnavailableError(f"Unsupported activity model: {settings.activity_model}")