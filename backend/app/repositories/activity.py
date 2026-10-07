from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.entities import ActivityLog, ModelPrediction


def latest_activity(db: Session, user_id: str) -> ActivityLog | None:
    return db.scalar(select(ActivityLog).where(ActivityLog.user_id == user_id).order_by(ActivityLog.start_time.desc()).limit(1))


def activity_history(db: Session, user_id: str, limit: int, offset: int) -> list[ActivityLog]:
    return list(db.scalars(
        select(ActivityLog).where(ActivityLog.user_id == user_id).order_by(ActivityLog.start_time.desc()).offset(offset).limit(limit)
    ))


def latest_prediction(db: Session, user_id: str) -> ModelPrediction | None:
    return db.scalar(
        select(ModelPrediction).where(ModelPrediction.user_id == user_id)
        .order_by(ModelPrediction.prediction_timestamp.desc()).limit(1)
    )


def predictions_since(db: Session, user_id: str, since: datetime) -> list[ModelPrediction]:
    return list(db.scalars(
        select(ModelPrediction).where(ModelPrediction.user_id == user_id, ModelPrediction.prediction_timestamp >= since)
    ))