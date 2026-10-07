from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.entities import StepLog


def get_step_log(db: Session, user_id: str, log_date: date) -> StepLog | None:
    return db.scalar(select(StepLog).where(StepLog.user_id == user_id, StepLog.log_date == log_date))


def step_history(db: Session, user_id: str, start: date, end: date) -> list[StepLog]:
    return list(db.scalars(
        select(StepLog).where(StepLog.user_id == user_id, StepLog.log_date >= start, StepLog.log_date <= end)
        .order_by(StepLog.log_date)
    ))