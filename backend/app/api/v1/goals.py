from fastapi import APIRouter, HTTPException

from app.api.deps import CurrentUser, DbSession
from app.models.entities import UserGoal
from app.repositories.goals import get_goals
from app.schemas.contracts import GoalRead, GoalWrite

router = APIRouter()


@router.post("", response_model=GoalRead, status_code=201)
def create_goals(payload: GoalWrite, db: DbSession, user: CurrentUser) -> UserGoal:
    if get_goals(db, user.id):
        raise HTTPException(status_code=409, detail="Goals already exist; use PUT to update them")
    goals = UserGoal(user_id=user.id, **payload.model_dump())
    db.add(goals)
    db.commit()
    db.refresh(goals)
    return goals


@router.get("", response_model=GoalRead)
def read_goals(db: DbSession, user: CurrentUser) -> UserGoal:
    goals = get_goals(db, user.id)
    if goals is None:
        goals = UserGoal(user_id=user.id)
        db.add(goals)
        db.commit()
        db.refresh(goals)
    return goals


@router.put("", response_model=GoalRead)
def update_goals(payload: GoalWrite, db: DbSession, user: CurrentUser) -> UserGoal:
    goals = get_goals(db, user.id)
    if goals is None:
        goals = UserGoal(user_id=user.id, **payload.model_dump())
        db.add(goals)
    else:
        for field, value in payload.model_dump().items():
            setattr(goals, field, value)
    db.commit()
    db.refresh(goals)
    return goals