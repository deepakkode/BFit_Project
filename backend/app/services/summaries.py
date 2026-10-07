from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.entities import ActivityLog, DailySummary, StepLog


def refresh_daily_summary(db: Session, user_id: str, summary_date: date) -> DailySummary:
    durations = db.execute(
        select(ActivityLog.activity, func.sum(ActivityLog.duration_seconds))
        .where(ActivityLog.user_id == user_id, func.date(ActivityLog.start_time) == summary_date)
        .group_by(ActivityLog.activity)
    ).all()
    step_totals = db.execute(
        select(
            func.coalesce(func.sum(StepLog.steps), 0),
            func.coalesce(func.sum(StepLog.distance_km), 0),
            func.coalesce(func.sum(StepLog.calories_burned), 0),
        ).where(StepLog.user_id == user_id, StepLog.log_date == summary_date)
    ).one()
    values = {f"{activity.lower()}_minutes": int(seconds // 60) for activity, seconds in durations}
    summary = db.scalar(select(DailySummary).where(
        DailySummary.user_id == user_id, DailySummary.summary_date == summary_date,
    ))
    if summary is None:
        summary = DailySummary(user_id=user_id, summary_date=summary_date)
        db.add(summary)
    for field in ("walking_minutes", "running_minutes", "sitting_minutes", "standing_minutes"):
        setattr(summary, field, values.get(field, 0))
    summary.total_steps = int(step_totals[0])
    summary.total_distance = float(step_totals[1])
    summary.total_calories = float(step_totals[2])
    return summary