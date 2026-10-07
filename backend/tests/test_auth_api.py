from collections.abc import Generator

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.database.base import Base
from app.database.session import get_db
from app.main import app
from app.models.entities import User


def test_register_login_and_profile() -> None:
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)

    def override_db() -> Generator[Session, None, None]:
        with Session(engine) as session:
            yield session

    app.dependency_overrides[get_db] = override_db
    try:
        with TestClient(app) as client:
            registered = client.post("/api/v1/auth/register", json={
                "name": "Activity User",
                "email": "USER@example.com",
                "password": "correct horse battery staple",
                "age": 30,
            })
            assert registered.status_code == 201
            assert registered.json()["email"] == "user@example.com"
            assert "password_hash" not in registered.json()

            duplicate = client.post("/api/v1/auth/register", json={
                "name": "Duplicate User",
                "email": "  USER@EXAMPLE.COM  ",
                "password": "another correct password",
            })
            assert duplicate.status_code == 409

            invalid_email = client.post("/api/v1/auth/register", json={
                "name": "Invalid User",
                "email": "not-an-email",
                "password": "correct horse battery staple",
            })
            assert invalid_email.status_code == 422

            short_password = client.post("/api/v1/auth/register", json={
                "name": "Weak Password",
                "email": "weak@example.com",
                "password": "short",
            })
            assert short_password.status_code == 422

            login = client.post("/api/v1/auth/login", json={
                "email": " USER@EXAMPLE.COM ",
                "password": "correct horse battery staple",
            })
            assert login.status_code == 200
            token = login.json()["access_token"]

            profile = client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {token}"})
            assert profile.status_code == 200
            assert profile.json()["name"] == "Activity User"

            current_activity = client.get("/api/v1/activity/current", headers={"Authorization": f"Bearer {token}"})
            assert current_activity.status_code == 200
            assert current_activity.json()["prediction_timestamp"] is None

            updated_profile = client.put("/api/v1/auth/profile", headers={"Authorization": f"Bearer {token}"}, json={
                "age": 31,
                "height_cm": 172,
                "weight_kg": 68,
            })
            assert updated_profile.status_code == 200
            assert updated_profile.json()["age"] == 31
            assert updated_profile.json()["height_cm"] == 172
            assert updated_profile.json()["weight_kg"] == 68

            refreshed_profile = client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {token}"})
            assert refreshed_profile.json()["age"] == 31
            assert refreshed_profile.json()["height_cm"] == 172
            assert refreshed_profile.json()["weight_kg"] == 68

            invalid_profile = client.put("/api/v1/auth/profile", headers={"Authorization": f"Bearer {token}"}, json={
                "age": 12,
                "height_cm": 172,
                "weight_kg": 68,
            })
            assert invalid_profile.status_code == 422

            saved_goals = client.put("/api/v1/goals", headers={"Authorization": f"Bearer {token}"}, json={
                "daily_step_goal": 6000,
                "weekly_running_goal": 3,
                "monthly_distance_goal": 50,
            })
            assert saved_goals.status_code == 200
            assert client.get("/api/v1/goals", headers={"Authorization": f"Bearer {token}"}).json()["daily_step_goal"] == 6000

            bad_login = client.post("/api/v1/auth/login", json={
                "email": "user@example.com",
                "password": "incorrect-password",
            })
            assert bad_login.status_code == 401

        with Session(engine) as session:
            assert session.scalar(select(func.count()).select_from(User)) == 1
    finally:
        app.dependency_overrides.clear()
        engine.dispose()