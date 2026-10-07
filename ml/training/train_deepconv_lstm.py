import argparse
import json
import os
import random
from pathlib import Path

import numpy as np
import torch
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score, precision_score, recall_score
from sklearn.model_selection import GroupShuffleSplit
from torch import nn
from torch.utils.data import DataLoader, TensorDataset

from backend.app.ml.deepconv_lstm import DeepConvLSTM
from ml.training.train_random_forest import (
    TARGET_LABELS,
    load_kaggle_split,
    load_wisdm,
    make_sequence_windows,
)

CLASS_NAMES = ["Walking", "Running", "Sitting", "Standing"]
DEFAULT_SEED = 42


def normalize_sensor_windows(
    train_windows: np.ndarray,
    evaluation_windows: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    mean = train_windows.mean(axis=(0, 1), dtype=np.float64).astype(np.float32)
    std = train_windows.std(axis=(0, 1), dtype=np.float64).astype(np.float32)
    std[std < 1e-6] = 1.0
    train = ((train_windows - mean) / std).astype(np.float32)
    evaluation = ((evaluation_windows - mean) / std).astype(np.float32)
    return train, evaluation, mean, std


def load_dataset_splits(dataset: Path) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, str, str]:
    if dataset.is_dir():
        train_path = dataset / "train.csv"
        test_path = dataset / "test.csv"
        if not train_path.is_file() or not test_path.is_file():
            raise ValueError(f"Expected train.csv and test.csv in {dataset}")
        train_windows, train_labels, _ = make_sequence_windows(load_kaggle_split(train_path))
        test_windows, test_labels, _ = make_sequence_windows(load_kaggle_split(test_path))
        return train_windows, train_labels, test_windows, test_labels, "provided_train_test", "WISDM Kaggle wangboluo/mcm2024"

    frame = load_wisdm(dataset)
    windows, labels, groups = make_sequence_windows(frame)
    splitter = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=DEFAULT_SEED)
    train_indices, test_indices = next(splitter.split(windows, labels, groups))
    split = "grouped_by_subject"
    return windows[train_indices], labels[train_indices], windows[test_indices], labels[test_indices], split, "WISDM"


def class_weights(labels: np.ndarray) -> torch.Tensor:
    encoded = np.asarray([CLASS_NAMES.index(str(label)) for label in labels], dtype=np.int64)
    counts = np.bincount(encoded, minlength=len(CLASS_NAMES)).astype(np.float32)
    weights = np.sqrt(len(encoded) / (len(CLASS_NAMES) * np.maximum(counts, 1)))
    weights /= weights.mean()
    return torch.tensor(weights, dtype=torch.float32)


def evaluate(model: DeepConvLSTM, windows: np.ndarray, labels: np.ndarray, device: torch.device) -> tuple[np.ndarray, float]:
    model.eval()
    outputs: list[np.ndarray] = []
    loader = DataLoader(TensorDataset(torch.from_numpy(windows)), batch_size=256, shuffle=False)
    with torch.inference_mode():
        for (batch,) in loader:
            outputs.append(model(batch.to(device)).cpu().numpy())
    logits = np.concatenate(outputs)
    predictions = np.asarray(CLASS_NAMES)[logits.argmax(axis=1)]
    return predictions, accuracy_score(labels, predictions)


def train(
    dataset: Path,
    artifact: Path,
    metrics_path: Path,
    epochs: int = 20,
    batch_size: int = 128,
    seed: int = DEFAULT_SEED,
) -> dict:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.set_num_threads(max(1, min(4, os.cpu_count() or 1)))

    x_train, y_train, x_test, y_test, split_name, dataset_name = load_dataset_splits(dataset)
    for label_set_name, split_labels in (("training", y_train), ("test", y_test)):
        if not TARGET_LABELS.issubset(set(split_labels)):
            raise ValueError(f"{label_set_name} split must contain all four target classes; found {sorted(set(split_labels))}")

    x_train, x_test, axis_mean, axis_std = normalize_sensor_windows(x_train, x_test)
    y_train_ids = np.asarray([CLASS_NAMES.index(str(label)) for label in y_train], dtype=np.int64)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = DeepConvLSTM(num_classes=len(CLASS_NAMES)).to(device)
    loss_function = nn.CrossEntropyLoss(weight=class_weights(y_train).to(device))
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=max(1, epochs))
    loader = DataLoader(
        TensorDataset(torch.from_numpy(x_train), torch.from_numpy(y_train_ids)),
        batch_size=batch_size,
        shuffle=True,
        generator=torch.Generator().manual_seed(seed),
    )

    for _ in range(epochs):
        model.train()
        for batch_windows, batch_labels in loader:
            batch_windows = batch_windows.to(device)
            batch_labels = batch_labels.to(device)
            optimizer.zero_grad(set_to_none=True)
            loss = loss_function(model(batch_windows), batch_labels)
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()
        scheduler.step()

    predictions, accuracy = evaluate(model, x_test, y_test, device)
    report = classification_report(y_test, predictions, labels=CLASS_NAMES, output_dict=True, zero_division=0)
    metrics = {
        "accuracy": float(accuracy),
        "precision_weighted": float(precision_score(y_test, predictions, average="weighted", zero_division=0)),
        "recall_weighted": float(recall_score(y_test, predictions, average="weighted", zero_division=0)),
        "f1_weighted": float(f1_score(y_test, predictions, average="weighted", zero_division=0)),
        "f1_macro": float(f1_score(y_test, predictions, average="macro", zero_division=0)),
        "confusion_matrix": confusion_matrix(y_test, predictions, labels=CLASS_NAMES).tolist(),
        "class_labels": CLASS_NAMES,
        "classification_report": report,
        "split": split_name,
        "dataset": dataset_name,
        "architecture": "DeepConvLSTM",
        "epochs": epochs,
        "batch_size": batch_size,
        "window_samples": int(x_train.shape[1]),
        "window_overlap_samples": int(x_train.shape[1] // 2),
        "train_windows": int(len(y_train)),
        "test_windows": int(len(y_test)),
        "seed": seed,
        "device": str(device),
    }
    artifact.parent.mkdir(parents=True, exist_ok=True)
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    torch.save({
        "model_state_dict": model.cpu().state_dict(),
        "model_config": {"num_classes": len(CLASS_NAMES)},
        "class_labels": CLASS_NAMES,
        "axis_mean": axis_mean,
        "axis_std": axis_std,
        "version": "2.0.0",
        "metrics": metrics,
    }, artifact)
    metrics_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    return metrics


def main() -> None:
    parser = argparse.ArgumentParser(description="Train and evaluate DeepConvLSTM on WISDM smartphone accelerometer data")
    parser.add_argument("dataset", type=Path, help="WISDM raw file or a directory containing train.csv and test.csv")
    parser.add_argument("--artifact", type=Path, default=Path("ml/artifacts/deepconv_lstm.pt"))
    parser.add_argument("--metrics", type=Path, default=Path("ml/artifacts/deepconv_lstm_metrics.json"))
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=128)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    args = parser.parse_args()
    metrics = train(args.dataset, args.artifact, args.metrics, args.epochs, args.batch_size, args.seed)
    print(json.dumps({key: value for key, value in metrics.items() if key not in {"classification_report"}}, indent=2))


if __name__ == "__main__":
    main()