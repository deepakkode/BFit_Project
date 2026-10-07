from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

ActivityName = Literal["Walking", "Running", "Sitting", "Standing"]


class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    age: int | None = Field(default=None, ge=13, le=120)
    height_cm: float | None = Field(default=None, gt=0, le=260)
    weight_kg: float | None = Field(default=None, gt=0, le=500)
    gender: str | None = Field(default=None, max_length=32)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: object) -> object:
        return value.strip().lower() if isinstance(value, str) else value


class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: object) -> object:
        return value.strip().lower() if isinstance(value, str) else value


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    email: EmailStr
    age: int | None
    height_cm: float | None
    weight_kg: float | None
    gender: str | None
    timezone: str


class UserProfileUpdate(BaseModel):
    age: int = Field(ge=13, le=120)
    height_cm: float = Field(gt=0, le=260)
    weight_kg: float = Field(gt=0, le=500)


class TokenRead(BaseModel):
    access_token: str
    token_type: str = "bearer"


class SensorSample(BaseModel):
    timestamp: datetime
    acc_x: float
    acc_y: float
    acc_z: float
    gyro_x: float | None = None
    gyro_y: float | None = None
    gyro_z: float | None = None


class PredictionRequest(BaseModel):
    window_start: datetime
    sample_rate_hz: float = Field(gt=0, le=200)
    samples: list[SensorSample] = Field(min_length=20, max_length=1000)


class PredictionRead(BaseModel):
    prediction_id: str
    activity: ActivityName
    confidence_score: float
    model_name: str
    model_version: str | None
    prediction_timestamp: datetime


class StepUpdate(BaseModel):
    log_date: date
    steps: int = Field(ge=0)
    distance_km: float = Field(ge=0)
    calories_burned: float = Field(ge=0)


class StepRead(StepUpdate):
    id: str
    model_config = ConfigDict(from_attributes=True)


class GoalWrite(BaseModel):
    daily_step_goal: int = Field(gt=0, le=100000)
    weekly_running_goal: int = Field(ge=0, le=100)
    monthly_distance_goal: float = Field(ge=0, le=10000)


class GoalRead(GoalWrite):
    id: str
    model_config = ConfigDict(from_attributes=True)


class ActivityRead(BaseModel):
    id: str
    activity: ActivityName
    confidence_score: float
    start_time: datetime
    end_time: datetime | None
    duration_seconds: int


class DailySummaryRead(BaseModel):
    summary_date: date
    walking_minutes: int
    running_minutes: int
    sitting_minutes: int
    standing_minutes: int
    total_steps: int
    total_distance: float
    total_calories: float