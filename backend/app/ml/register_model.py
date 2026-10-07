import argparse
import json
from pathlib import Path

from sqlalchemy import select

from app.database.session import SessionLocal
from app.models.entities import ModelVersion


def register_model(model_name: str, version: str, artifact_path: Path, metrics_path: Path) -> None:
    metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
    with SessionLocal() as db:
        model_version = db.scalar(select(ModelVersion).where(
            ModelVersion.model_name == model_name,
            ModelVersion.version == version,
        ))
        if model_version is None:
            model_version = ModelVersion(
                model_name=model_name,
                version=version,
                artifact_uri=str(artifact_path.resolve()),
                metrics=metrics,
            )
            db.add(model_version)
        else:
            model_version.artifact_uri = str(artifact_path.resolve())
            model_version.metrics = metrics
        db.commit()


def main() -> None:
    parser = argparse.ArgumentParser(description="Register trained model metadata and evaluation metrics in PostgreSQL")
    parser.add_argument("--model-name", default="random_forest")
    parser.add_argument("--version", default="1.0.0")
    parser.add_argument("--artifact", type=Path, default=Path("../ml/artifacts/random_forest.joblib"))
    parser.add_argument("--metrics", type=Path, default=Path("../ml/artifacts/metrics.json"))
    args = parser.parse_args()
    if not args.artifact.is_file() or not args.metrics.is_file():
        parser.error("Both model artifact and metrics file must exist")
    register_model(args.model_name, args.version, args.artifact, args.metrics)
    print(f"Registered {args.model_name}:{args.version}")


if __name__ == "__main__":
    main()