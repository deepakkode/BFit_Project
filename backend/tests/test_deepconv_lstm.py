import torch
import numpy as np
import pytest
from datetime import datetime, timezone

from app.core.config import settings
from app.ml.predictor import DeepConvLSTMPredictor, ModelUnavailableError
from app.ml.predictor import RandomForestPredictor, create_activity_predictor
from app.schemas.contracts import SensorSample
from app.ml.deepconv_lstm import DeepConvLSTM
from ml.training.train_deepconv_lstm import normalize_sensor_windows


def test_deepconv_lstm_returns_four_class_logits_and_backpropagates() -> None:
    model = DeepConvLSTM(dropout=0.0)
    samples = torch.randn(2, 200, 3)

    logits = model(samples)
    loss = logits.square().mean()
    loss.backward()

    assert logits.shape == (2, 4)
    assert torch.isfinite(logits).all()
    assert model.classifier.weight.grad is not None


def test_normalization_uses_training_statistics_for_evaluation_windows() -> None:
    train = torch.arange(2 * 4 * 3, dtype=torch.float32).numpy().reshape(2, 4, 3)
    evaluation = torch.full((1, 4, 3), 100.0).numpy()

    normalized_train, normalized_evaluation, mean, std = normalize_sensor_windows(train, evaluation)

    assert np.allclose(normalized_train.mean(axis=(0, 1)), 0.0, atol=1e-6)
    assert mean.shape == (3,)
    assert std.shape == (3,)
    assert normalized_evaluation.mean() > 0


def test_deepconv_predictor_loads_checkpoint_and_returns_confidence(tmp_path) -> None:
    labels = ["Walking", "Running", "Sitting", "Standing"]
    model = DeepConvLSTM(num_classes=len(labels))
    artifact_path = tmp_path / "deepconv_lstm.pt"
    torch.save({
        "model_state_dict": model.state_dict(),
        "model_config": {"num_classes": len(labels)},
        "class_labels": labels,
        "axis_mean": np.zeros(3, dtype=np.float32),
        "axis_std": np.ones(3, dtype=np.float32),
        "version": "2.0.0",
    }, artifact_path)
    samples = [
        SensorSample(timestamp=datetime(2026, 1, 1, tzinfo=timezone.utc), acc_x=0.1, acc_y=0.2, acc_z=9.7)
        for _ in range(200)
    ]

    activity, confidence = DeepConvLSTMPredictor(str(artifact_path)).predict(samples)

    assert activity in labels
    assert 0 <= confidence <= 1


def test_deepconv_predictor_reports_missing_checkpoint(tmp_path) -> None:
    predictor = DeepConvLSTMPredictor(str(tmp_path / "missing.pt"))

    with pytest.raises(ModelUnavailableError, match="Model artifact not found"):
        predictor.predict([])


def test_auto_model_selection_prefers_deepconv_when_checkpoint_exists(tmp_path, monkeypatch) -> None:
    checkpoint = tmp_path / "deepconv_lstm.pt"
    checkpoint.touch()
    monkeypatch.setattr(settings, "activity_model", "auto")
    monkeypatch.setattr(settings, "deepconv_lstm_artifact_path", str(checkpoint))

    assert isinstance(create_activity_predictor(), DeepConvLSTMPredictor)


def test_auto_model_selection_falls_back_to_random_forest_without_checkpoint(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(settings, "activity_model", "auto")
    monkeypatch.setattr(settings, "deepconv_lstm_artifact_path", str(tmp_path / "missing.pt"))

    assert isinstance(create_activity_predictor(), RandomForestPredictor)