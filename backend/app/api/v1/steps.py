from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Query
from sqlalchemy.dialects.postgresql import insert

from app.api.deps import CurrentUser, DbSession
from app.models.entities import StepLog, new_id
from app.repositories.steps import get_step_log, step_history
from app.schemas.contracts import StepRead, StepUpdate
from app.services.summaries import refresh_daily_summary

router = APIRouter()


@router.post("/update", response_model=StepRead)
def update_steps(payload: StepUpdate, db: DbSession, user: CurrentUser) -> StepLog:
    values = payload.model_dump()
    statement = insert(StepLog).values(id=new_id(), user_id=user.id, **values)
    statement = statement.on_conflict_do_update(
        index_elements=[StepLog.user_id, StepLog.log_date],
        set_={field: getattr(statement.excluded, field) for field in values if field != "log_date"},
    ).returning(StepLog)
    row = db.scalar(statement)
    refresh_daily_summary(db, user.id, payload.log_date)
    db.commit()
    db.refresh(row)
    return row


@router.get("/today")
def today_steps(db: DbSession, user: CurrentUser) -> dict:
    today = datetime.now(timezone.utc).date()
    row = get_step_log(db, user.id, today)
    return row if row else {"log_date": today, "steps": 0, "distance_km": 0, "calories_burned": 0}


@router.get("/history", response_model=list[StepRead])
def history(
    db: DbSession, user: CurrentUser,
    start: date = Query(default_factory=lambda: datetime.now(timezone.utc).date() - timedelta(days=29)),
    end: date = Query(default_factory=lambda: datetime.now(timezone.utc).date()),
) -> list[StepLog]:
    if end < start or (end - start).days > 366:
        from fastapi import HTTPException
        raise HTTPException(status_code=422, detail="Date range must be ordered and no longer than 367 days")
    return step_history(db, user.id, start, end)