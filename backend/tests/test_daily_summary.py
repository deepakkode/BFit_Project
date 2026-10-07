from datetime import date, datetime, timezone

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.database.base import Base
from app.models.entities import ActivityLog, DailySummary, StepLog, User
from app.services.summaries import refresh_daily_summary


def test_refresh_daily_summary_aggregates_activity_and_steps() -> None:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    today = date(2026, 10, 6)
    with Session(engine) as db:
        user = User(name="Test", email="test@example.com", password_hash="hash")
        db.add(user)
        db.flush()
        db.add(ActivityLog(
            user_id=user.id, activity="Walking", confidence_score=0.9,
            start_time=datetime(2026, 10, 6, 8, tzinfo=timezone.utc),
            end_time=datetime(2026, 10, 6, 8, 10, tzinfo=timezone.utc), duration_seconds=600,
        ))
        db.add(StepLog(user_id=user.id, log_date=today, steps=1234, distance_km=0.9, calories_burned=42))
        db.flush()

        summary = refresh_daily_summary(db, user.id, today)
        db.flush()

        saved = db.scalar(select(DailySummary).where(DailySummary.user_id == user.id, DailySummary.summary_date == today))
        assert saved is summary
        assert summary.walking_minutes == 10
        assert summary.total_steps == 1234
        assert summary.total_distance == 0.9
        assert summary.total_calories == 42