from datetime import datetime, timezone

import numpy as np
import pandas as pd
import pytest

from app.ml.predictor import ModelUnavailableError, RandomForestPredictor, extract_features
from app.schemas.contracts import SensorSample
from ml.training.train_random_forest import WINDOW_SIZE, load_kaggle_split, make_sequence_windows, make_windows


def sensor_window() -> list[SensorSample]:
    return [
        SensorSample(
            timestamp=datetime(2026, 1, 1, tzinfo=timezone.utc),
            acc_x=float(index) / 100,
            acc_y=0.5,
            acc_z=9.8,
        )
        for index in range(20)
    ]


def test_feature_extraction_returns_21_finite_features() -> None:
    features = extract_features(sensor_window())

    assert features.shape == (1, 21)
    assert np.isfinite(features).all()


def test_predictor_reports_missing_artifact(tmp_path) -> None:
    predictor = RandomForestPredictor(str(tmp_path / "missing.joblib"))

    with pytest.raises(ModelUnavailableError, match="Model artifact not found"):
        predictor.predict(sensor_window())


def test_wisdm_windows_do_not_cross_recording_gaps() -> None:
    timestamps = [index * 50 for index in range(WINDOW_SIZE)]
    timestamps += [20000 + index * 50 for index in range(WINDOW_SIZE)]
    frame = pd.DataFrame({
        "user_id": [1] * len(timestamps),
        "activity": ["walking"] * len(timestamps),
        "timestamp": timestamps,
        "x": [0.1] * len(timestamps),
        "y": [0.2] * len(timestamps),
        "z": [9.8] * len(timestamps),
    })

    features, labels, groups = make_windows(frame)

    assert features.shape == (2, 21)
    assert labels.tolist() == ["Walking", "Walking"]
    assert groups.tolist() == ["1", "1"]


def test_sequence_windows_preserve_raw_time_series_axes() -> None:
    frame = pd.DataFrame({
        "user_id": ["one"] * WINDOW_SIZE,
        "activity": ["walking"] * WINDOW_SIZE,
        "timestamp": np.arange(WINDOW_SIZE) * 0.05,
        "x": np.arange(WINDOW_SIZE, dtype=float),
        "y": np.ones(WINDOW_SIZE),
        "z": np.full(WINDOW_SIZE, 9.8),
    })

    sequences, labels, groups = make_sequence_windows(frame)

    assert sequences.shape == (1, WINDOW_SIZE, 3)
    assert sequences[0, :, 0].tolist() == np.arange(WINDOW_SIZE, dtype=float).tolist()
    assert labels.tolist() == ["Walking"]
    assert groups.tolist() == ["one"]


def test_kaggle_wisdm_codes_map_to_supported_activity_labels(tmp_path) -> None:
    rows = []
    timestamp = 0.0
    for activity_code in range(6):
        for sample in range(WINDOW_SIZE):
            rows.append({
                "acc_x": sample / 100,
                "acc_y": 0.5,
                "acc_z": 9.8,
                "timestamp": timestamp,
                "Activity": activity_code,
            })
            if sample % 20 != 0:
                timestamp += 0.05
    csv_path = tmp_path / "train.csv"
    pd.DataFrame(rows).to_csv(csv_path, index=False)

    frame = load_kaggle_split(csv_path)
    _, labels, groups = make_windows(frame)

    assert labels.tolist() == ["Walking", "Running", "Sitting", "Standing", "Walking", "Walking"]
    assert set(groups) == {"provided_split"}