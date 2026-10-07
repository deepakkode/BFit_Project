import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score, precision_score, recall_score
from sklearn.model_selection import GroupShuffleSplit

WINDOW_SIZE = 200
WINDOW_STEP = 100
WISDM_LABELS = {
    "walking": "Walking",
    "jogging": "Running",
    "running": "Running",
    "sitting": "Sitting",
    "standing": "Standing",
    "downstairs": "Walking",
    "upstairs": "Walking",
    "upstair": "Walking",
}
KAGGLE_LABELS = {
    0: "Walking",
    1: "Running",
    2: "Sitting",
    3: "Standing",
    4: "Walking",
    5: "Walking",
}
TARGET_LABELS = {"Walking", "Running", "Sitting", "Standing"}


def extract_features(axes: np.ndarray) -> np.ndarray:
    magnitude = np.linalg.norm(axes, axis=1)
    values = [*axes.mean(axis=0), *axes.std(axis=0), *axes.min(axis=0), *axes.max(axis=0), *np.ptp(axes, axis=0)]
    values.extend([magnitude.mean(), magnitude.std(), magnitude.min(), magnitude.max(), np.ptp(magnitude), np.sqrt(np.mean(magnitude**2))])
    return np.asarray(values, dtype=np.float64)


def load_wisdm(path: Path) -> pd.DataFrame:
    columns = ["user_id", "activity", "timestamp", "x", "y", "z"]
    frame = pd.read_csv(path, header=None, names=columns, sep=r",\s*", engine="python", on_bad_lines="skip")
    frame["z"] = frame["z"].astype(str).str.rstrip(";")
    frame["activity"] = frame["activity"].str.strip().str.lower()
    for axis in ("x", "y", "z"):
        frame[axis] = pd.to_numeric(frame[axis], errors="coerce")
    frame["timestamp"] = pd.to_numeric(frame["timestamp"], errors="coerce")
    frame = frame.dropna(subset=["user_id", "activity", "timestamp", "x", "y", "z"])
    frame = frame[frame["activity"].isin(WISDM_LABELS)].copy()
    frame["source_activity"] = frame["activity"]
    frame["activity"] = frame["activity"].map(WISDM_LABELS)
    return frame.sort_values(["user_id", "timestamp"]).reset_index(drop=True)


def load_kaggle_split(path: Path) -> pd.DataFrame:
    frame = pd.read_csv(path)
    required = {"acc_x", "acc_y", "acc_z", "timestamp", "Activity"}
    missing = required.difference(frame.columns)
    if missing:
        raise ValueError(f"{path} is missing required columns: {sorted(missing)}")

    activity_ids = pd.to_numeric(frame["Activity"], errors="coerce")
    unknown = sorted(set(activity_ids.dropna().astype(int)) - KAGGLE_LABELS.keys())
    if unknown:
        raise ValueError(f"{path} contains unmapped WISDM Activity codes: {unknown}")

    for column in ("acc_x", "acc_y", "acc_z", "timestamp"):
        frame[column] = pd.to_numeric(frame[column], errors="coerce")
    frame = frame.dropna(subset=["acc_x", "acc_y", "acc_z", "timestamp", "Activity"]).copy()
    frame["source_activity"] = activity_ids.loc[frame.index].astype(int).astype(str)
    frame["activity"] = activity_ids.loc[frame.index].astype(int).map(KAGGLE_LABELS)
    frame["user_id"] = "provided_split"
    return frame.rename(columns={"acc_x": "x", "acc_y": "y", "acc_z": "z"})[
        ["user_id", "activity", "source_activity", "timestamp", "x", "y", "z"]
    ].reset_index(drop=True)


def make_sequence_windows(frame: pd.DataFrame) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    windows: list[np.ndarray] = []
    labels: list[str] = []
    groups: list[str] = []
    ordered = frame.reset_index(drop=True)
    timestamps = ordered["timestamp"].to_numpy(dtype=np.float64)
    activities = ordered["activity"].to_numpy()
    source_activities = ordered["source_activity"].to_numpy() if "source_activity" in ordered else activities
    users = ordered["user_id"].astype(str).to_numpy() if "user_id" in ordered else np.repeat("unknown", len(ordered))
    axes = ordered[["x", "y", "z"]].to_numpy(dtype=np.float64)

    deltas = np.diff(timestamps)
    positive_deltas = deltas[deltas > 0]
    if not len(positive_deltas):
        raise ValueError("Sensor timestamps must increase within each recording")
    gap_threshold = float(np.median(positive_deltas)) * 5
    boundaries = np.flatnonzero(
        (activities[1:] != activities[:-1])
        | (source_activities[1:] != source_activities[:-1])
        | (users[1:] != users[:-1])
        | (deltas < 0)
        | (deltas > gap_threshold)
    ) + 1

    sequence_starts = np.concatenate(([0], boundaries))
    sequence_ends = np.concatenate((boundaries, [len(ordered)]))
    for start_index, end_index in zip(sequence_starts, sequence_ends):
        sequence = axes[start_index:end_index]
        if not len(sequence):
            continue
        activity_value = str(activities[start_index])
        activity = WISDM_LABELS.get(activity_value.strip().lower(), activity_value)
        user_id = str(users[start_index])
        for start in range(0, len(sequence) - WINDOW_SIZE + 1, WINDOW_STEP):
            windows.append(sequence[start:start + WINDOW_SIZE])
            labels.append(activity)
            groups.append(user_id)
    if not windows:
        raise ValueError(f"No complete {WINDOW_SIZE}-sample WISDM windows found")
    return np.stack(windows), np.asarray(labels), np.asarray(groups)


def make_windows(frame: pd.DataFrame) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    sequences, labels, groups = make_sequence_windows(frame)
    features = np.stack([extract_features(window) for window in sequences])
    return features, labels, groups


def train(dataset: Path, artifact: Path, metrics_path: Path) -> dict:
    if dataset.is_dir():
        train_path = dataset / "train.csv"
        test_path = dataset / "test.csv"
        if not train_path.is_file() or not test_path.is_file():
            raise ValueError(f"Expected train.csv and test.csv in {dataset}")
        x_train, y_train, _ = make_windows(load_kaggle_split(train_path))
        x_test, y_test, _ = make_windows(load_kaggle_split(test_path))
        split_name = "provided_train_test"
        train_subjects: list[str] = []
        test_subjects: list[str] = []
        dataset_name = "WISDM Kaggle wangboluo/mcm2024"
    else:
        frame = load_wisdm(dataset)
        x, y, groups = make_windows(frame)
        splitter = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=42)
        train_indices, test_indices = next(splitter.split(x, y, groups))
        x_train, y_train = x[train_indices], y[train_indices]
        x_test, y_test = x[test_indices], y[test_indices]
        split_name = "grouped_by_subject"
        train_subjects = sorted(set(groups[train_indices].tolist()))
        test_subjects = sorted(set(groups[test_indices].tolist()))
        dataset_name = "WISDM"

    for split_name_label, split_labels in (("training", y_train), ("test", y_test)):
        if not TARGET_LABELS.issubset(set(split_labels)):
            raise ValueError(f"{split_name_label} split must contain all four target classes; found {sorted(set(split_labels))}")

    model = RandomForestClassifier(
        n_estimators=400, max_features="sqrt", min_samples_leaf=2,
        class_weight="balanced_subsample", random_state=42, n_jobs=-1,
    )
    model.fit(x_train, y_train)
    predictions = model.predict(x_test)
    class_names = ["Walking", "Running", "Sitting", "Standing"]
    metrics = {
        "accuracy": float(accuracy_score(y_test, predictions)),
        "precision_weighted": float(precision_score(y_test, predictions, average="weighted", zero_division=0)),
        "recall_weighted": float(recall_score(y_test, predictions, average="weighted", zero_division=0)),
        "f1_weighted": float(f1_score(y_test, predictions, average="weighted", zero_division=0)),
        "f1_macro": float(f1_score(y_test, predictions, average="macro", zero_division=0)),
        "confusion_matrix": confusion_matrix(y_test, predictions, labels=class_names).tolist(),
        "class_labels": class_names,
        "classification_report": classification_report(y_test, predictions, labels=class_names, output_dict=True, zero_division=0),
        "split": split_name,
        "train_subjects": train_subjects,
        "test_subjects": test_subjects,
        "window_samples": WINDOW_SIZE,
        "window_overlap_samples": WINDOW_SIZE - WINDOW_STEP,
        "train_windows": int(len(y_train)),
        "test_windows": int(len(y_test)),
        "source_label_mapping": {str(code): label for code, label in KAGGLE_LABELS.items()} if dataset.is_dir() else None,
    }
    artifact.parent.mkdir(parents=True, exist_ok=True)
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": model, "version": "1.0.0", "feature_count": x_train.shape[1], "dataset": dataset_name, "metrics": metrics}, artifact)
    metrics_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    return metrics


def main() -> None:
    parser = argparse.ArgumentParser(description="Train BFit Random Forest using WISDM smartphone accelerometer data")
    parser.add_argument("dataset", type=Path, help="WISDM raw file or a directory containing Kaggle train.csv and test.csv")
    parser.add_argument("--artifact", type=Path, default=Path("ml/artifacts/random_forest.joblib"))
    parser.add_argument("--metrics", type=Path, default=Path("ml/artifacts/metrics.json"))
    args = parser.parse_args()
    metrics = train(args.dataset, args.artifact, args.metrics)
    print(json.dumps({key: value for key, value in metrics.items() if key not in {"classification_report", "train_subjects", "test_subjects"}}, indent=2))


if __name__ == "__main__":
    main()