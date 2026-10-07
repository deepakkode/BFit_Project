from datetime import datetime, time, timedelta, timezone

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.ml.predictor import ModelUnavailableError, create_activity_predictor
from app.models.entities import ActivityLog, ModelPrediction
from app.repositories.activity import activity_history, latest_activity, latest_prediction
from app.schemas.contracts import ActivityRead, PredictionRead, PredictionRequest
from app.services.summaries import refresh_daily_summary

router = APIRouter()
predictor = create_activity_predictor()


@router.post("/predict", response_model=PredictionRead)
def predict(payload: PredictionRequest, db: DbSession, user: CurrentUser) -> PredictionRead:
    try:
        activity, confidence = predictor.predict(payload.samples)
    except ModelUnavailableError as exc:
        raise HTTPException(status_code=503, detail="Activity model is not trained or installed") from exc
    except (ValueError, OSError) as exc:
        raise HTTPException(status_code=503, detail="Activity model could not process this sensor window") from exc

    if activity not in {"Walking", "Running", "Sitting", "Standing"}:
        raise HTTPException(status_code=503, detail="Model returned an unsupported activity label")
    predicted_at = datetime.now(timezone.utc)
    prediction = ModelPrediction(
        user_id=user.id, model_name=predictor.model_name, predicted_activity=activity,
        confidence_score=confidence, prediction_timestamp=predicted_at,
    )
    db.add(prediction)
    previous = latest_activity(db, user.id)
    if previous and previous.activity == activity and previous.end_time and predicted_at - previous.end_time <= timedelta(minutes=2):
        previous.end_time = predicted_at
        previous.duration_seconds = max(0, int((predicted_at - previous.start_time).total_seconds()))
        previous.confidence_score = confidence
    else:
        db.add(ActivityLog(
            user_id=user.id, activity=activity, confidence_score=confidence,
            start_time=payload.window_start, end_time=predicted_at,
            duration_seconds=max(0, int((predicted_at - payload.window_start).total_seconds())),
        ))
    refresh_daily_summary(db, user.id, predicted_at.date())
    db.commit()
    db.refresh(prediction)
    return PredictionRead(
        prediction_id=prediction.id, activity=activity, confidence_score=confidence,
        model_name=predictor.model_name, model_version=predictor.version,
        prediction_timestamp=predicted_at,
    )


@router.get("/current")
def current_activity(db: DbSession, user: CurrentUser) -> dict:
    activity = latest_activity(db, user.id)
    prediction = latest_prediction(db, user.id)
    if activity is None:
        return {"activity": None, "confidence_score": None, "start_time": None, "prediction_timestamp": None, "duration_seconds": 0}
    return {
        "activity": activity.activity,
        "confidence_score": prediction.confidence_score if prediction else activity.confidence_score,
        "start_time": activity.start_time,
        "prediction_timestamp": prediction.prediction_timestamp if prediction else activity.end_time,
        "duration_seconds": activity.duration_seconds,
    }


@router.get("/history", response_model=list[ActivityRead])
def history(
    db: DbSession, user: CurrentUser,
    limit: int = Query(default=50, ge=1, le=200), offset: int = Query(default=0, ge=0),
) -> list[ActivityLog]:
    return activity_history(db, user.id, limit, offset)


@router.get("/today")
def today_activity(db: DbSession, user: CurrentUser) -> dict:
    today = datetime.now(timezone.utc).date()
    start = datetime.combine(today, time.min, tzinfo=timezone.utc)
    end = start + timedelta(days=1)
    rows = list(db.scalars(select(ActivityLog).where(
        ActivityLog.user_id == user.id, ActivityLog.start_time >= start, ActivityLog.start_time < end,
    ).order_by(ActivityLog.start_time.desc())))
    totals = {label: sum(item.duration_seconds for item in rows if item.activity == label) for label in ("Walking", "Running", "Sitting", "Standing")}
    logs = [
        {
            "id": item.id,
            "activity": item.activity,
            "confidence_score": item.confidence_score,
            "start_time": item.start_time,
            "end_time": item.end_time,
            "duration_seconds": item.duration_seconds,
        }
        for item in rows
    ]
    return {"date": today, "duration_seconds": totals, "logs": logs}