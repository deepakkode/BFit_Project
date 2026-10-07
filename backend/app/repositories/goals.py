from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.entities import UserGoal


def get_goals(db: Session, user_id: str) -> UserGoal | None:
    return db.scalar(select(UserGoal).where(UserGoal.user_id == user_id))