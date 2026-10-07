from calendar import monthrange
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Query
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.models.entities import ActivityLog, StepLog

router = APIRouter()
ACTIVITIES = ("Walking", "Running", "Sitting", "Standing")


def summaries(db: DbSession, user_id: str, start: date, end: date) -> list[dict]:
    logs = list(db.scalars(select(ActivityLog).where(
        ActivityLog.user_id == user_id,
        ActivityLog.start_time >= start,
        ActivityLog.start_time < end + timedelta(days=1),
    )))
    steps = list(db.scalars(select(StepLog).where(
        StepLog.user_id == user_id, StepLog.log_date >= start, StepLog.log_date <= end,
    )))
    by_day: dict[date, dict] = {}
    current = start
    while current <= end:
        by_day[current] = {
            "summary_date": current, "walking_minutes": 0, "running_minutes": 0,
            "sitting_minutes": 0, "standing_minutes": 0, "total_steps": 0,
            "total_distance": 0.0, "total_calories": 0.0,
        }
        current += timedelta(days=1)
    for log in logs:
        day = log.start_time.date()
        if day not in by_day:
            continue
        field = f"{log.activity.lower()}_minutes"
        by_day[day][field] += log.duration_seconds // 60
    for row in steps:
        item = by_day[row.log_date]
        item["total_steps"] += row.steps
        item["total_distance"] += row.distance_km
        item["total_calories"] += row.calories_burned
    return list(by_day.values())


@router.get("/daily")
def daily(db: DbSession, user: CurrentUser, summary_date: date = Query(alias="date", default_factory=lambda: datetime.now(timezone.utc).date())) -> dict:
    return summaries(db, user.id, summary_date, summary_date)[0]


@router.get("/weekly")
def weekly(db: DbSession, user: CurrentUser, week_start: date = Query(default_factory=lambda: datetime.now(timezone.utc).date() - timedelta(days=datetime.now(timezone.utc).date().weekday()))) -> dict:
    days = summaries(db, user.id, week_start, week_start + timedelta(days=6))
    return {"week_start": week_start, "days": days, "totals": {
        key: sum(day[key] for day in days) for key in (
            "walking_minutes", "running_minutes", "sitting_minutes", "standing_minutes",
            "total_steps", "total_distance", "total_calories",
        )
    }}


@router.get("/monthly")
def monthly(
    db: DbSession, user: CurrentUser,
    year: int = Query(default_factory=lambda: datetime.now(timezone.utc).year, ge=2000, le=2100),
    month: int = Query(default_factory=lambda: datetime.now(timezone.utc).month, ge=1, le=12),
) -> dict:
    start = date(year, month, 1)
    end = date(year, month, monthrange(year, month)[1])
    days = summaries(db, user.id, start, end)
    return {"year": year, "month": month, "days": days, "totals": {
        key: sum(day[key] for day in days) for key in (
            "walking_minutes", "running_minutes", "sitting_minutes", "standing_minutes",
            "total_steps", "total_distance", "total_calories",
        )
    }}