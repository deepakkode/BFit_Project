import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, DateTime, Float, ForeignKey, Index, Integer, JSON, String, UniqueConstraint, func, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


def new_id() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"
    __table_args__ = (Index("uq_users_email_ci", text("lower(email)"), unique=True),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str] = mapped_column(String(320), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    age: Mapped[int | None] = mapped_column(Integer)
    height_cm: Mapped[float | None] = mapped_column(Float)
    weight_kg: Mapped[float | None] = mapped_column(Float)
    gender: Mapped[str | None] = mapped_column(String(32))
    timezone: Mapped[str] = mapped_column(String(64), default="UTC", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    activity_logs: Mapped[list["ActivityLog"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    step_logs: Mapped[list["StepLog"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    goals: Mapped["UserGoal | None"] = relationship(back_populates="user", cascade="all, delete-orphan", uselist=False)


class ActivityLog(Base):
    __tablename__ = "activity_logs"
    __table_args__ = (
        CheckConstraint("activity IN ('Walking', 'Running', 'Sitting', 'Standing')", name="ck_activity_type"),
        CheckConstraint("confidence_score >= 0 AND confidence_score <= 1", name="ck_activity_confidence"),
        CheckConstraint("duration_seconds >= 0", name="ck_activity_duration"),
        CheckConstraint("end_time IS NULL OR end_time >= start_time", name="ck_activity_time_order"),
        Index("ix_activity_user_start", "user_id", "start_time"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    activity: Mapped[str] = mapped_column(String(16), nullable=False)
    confidence_score: Mapped[float] = mapped_column(Float, nullable=False)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    user: Mapped[User] = relationship(back_populates="activity_logs")


class StepLog(Base):
    __tablename__ = "step_logs"
    __table_args__ = (
        UniqueConstraint("user_id", "log_date", name="uq_step_user_date"),
        CheckConstraint("steps >= 0", name="ck_steps_nonnegative"),
        CheckConstraint("distance_km >= 0 AND calories_burned >= 0", name="ck_step_metrics_nonnegative"),
        Index("ix_steps_user_date", "user_id", "log_date"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    log_date: Mapped[date] = mapped_column(Date, nullable=False)
    steps: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    distance_km: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    calories_burned: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    user: Mapped[User] = relationship(back_populates="step_logs")


class DailySummary(Base):
    __tablename__ = "daily_summary"
    __table_args__ = (UniqueConstraint("user_id", "summary_date", name="uq_summary_user_date"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    summary_date: Mapped[date] = mapped_column(Date, nullable=False)
    walking_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    running_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    sitting_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    standing_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_steps: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_distance: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    total_calories: Mapped[float] = mapped_column(Float, default=0, nullable=False)


class ModelVersion(Base):
    __tablename__ = "model_versions"
    __table_args__ = (UniqueConstraint("model_name", "version", name="uq_model_version"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    model_name: Mapped[str] = mapped_column(String(80), nullable=False)
    version: Mapped[str] = mapped_column(String(40), nullable=False)
    artifact_uri: Mapped[str] = mapped_column(String(512), nullable=False)
    metrics: Mapped[dict] = mapped_column(JSON, nullable=False)
    trained_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ModelPrediction(Base):
    __tablename__ = "model_predictions"
    __table_args__ = (
        CheckConstraint("predicted_activity IN ('Walking', 'Running', 'Sitting', 'Standing')", name="ck_prediction_activity"),
        CheckConstraint("confidence_score >= 0 AND confidence_score <= 1", name="ck_prediction_confidence"),
        Index("ix_predictions_user_timestamp", "user_id", "prediction_timestamp"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    model_version_id: Mapped[str | None] = mapped_column(ForeignKey("model_versions.id", ondelete="SET NULL"))
    model_name: Mapped[str] = mapped_column(String(80), nullable=False)
    predicted_activity: Mapped[str] = mapped_column(String(16), nullable=False)
    confidence_score: Mapped[float] = mapped_column(Float, nullable=False)
    prediction_timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class UserGoal(Base):
    __tablename__ = "user_goals"
    __table_args__ = (
        CheckConstraint("daily_step_goal > 0", name="ck_daily_step_goal_positive"),
        CheckConstraint("weekly_running_goal >= 0", name="ck_weekly_running_goal_nonnegative"),
        CheckConstraint("monthly_distance_goal >= 0", name="ck_monthly_distance_goal_nonnegative"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    daily_step_goal: Mapped[int] = mapped_column(Integer, default=8000, nullable=False)
    weekly_running_goal: Mapped[int] = mapped_column(Integer, default=3, nullable=False)
    monthly_distance_goal: Mapped[float] = mapped_column(Float, default=50, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    user: Mapped[User] = relationship(back_populates="goals")