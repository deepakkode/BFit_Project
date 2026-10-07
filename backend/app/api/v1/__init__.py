from fastapi import APIRouter

from app.api.v1 import activity, analytics, auth, goals, steps

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(activity.router, prefix="/activity", tags=["activity"])
api_router.include_router(steps.router, prefix="/steps", tags=["steps"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(goals.router, prefix="/goals", tags=["goals"])