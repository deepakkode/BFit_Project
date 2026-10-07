"""Initial BFit schema.

Revision ID: 0001_initial
Revises:
"""
from alembic import op
import sqlalchemy as sa

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("age", sa.Integer()),
        sa.Column("height_cm", sa.Float()),
        sa.Column("weight_kg", sa.Float()),
        sa.Column("gender", sa.String(32)),
        sa.Column("timezone", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_table(
        "model_versions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("model_name", sa.String(80), nullable=False),
        sa.Column("version", sa.String(40), nullable=False),
        sa.Column("artifact_uri", sa.String(512), nullable=False),
        sa.Column("metrics", sa.JSON(), nullable=False),
        sa.Column("trained_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("model_name", "version", name="uq_model_version"),
    )
    op.create_table(
        "activity_logs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("activity", sa.String(16), nullable=False),
        sa.Column("confidence_score", sa.Float(), nullable=False),
        sa.Column("start_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_time", sa.DateTime(timezone=True)),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("activity IN ('Walking', 'Running', 'Sitting', 'Standing')", name="ck_activity_type"),
        sa.CheckConstraint("confidence_score >= 0 AND confidence_score <= 1", name="ck_activity_confidence"),
        sa.CheckConstraint("duration_seconds >= 0", name="ck_activity_duration"),
        sa.CheckConstraint("end_time IS NULL OR end_time >= start_time", name="ck_activity_time_order"),
    )
    op.create_index("ix_activity_user_start", "activity_logs", ["user_id", "start_time"])
    op.create_table(
        "step_logs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("log_date", sa.Date(), nullable=False),
        sa.Column("steps", sa.Integer(), nullable=False),
        sa.Column("distance_km", sa.Float(), nullable=False),
        sa.Column("calories_burned", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "log_date", name="uq_step_user_date"),
        sa.CheckConstraint("steps >= 0", name="ck_steps_nonnegative"),
        sa.CheckConstraint("distance_km >= 0 AND calories_burned >= 0", name="ck_step_metrics_nonnegative"),
    )
    op.create_index("ix_steps_user_date", "step_logs", ["user_id", "log_date"])
    op.create_table(
        "daily_summary",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("summary_date", sa.Date(), nullable=False),
        sa.Column("walking_minutes", sa.Integer(), nullable=False),
        sa.Column("running_minutes", sa.Integer(), nullable=False),
        sa.Column("sitting_minutes", sa.Integer(), nullable=False),
        sa.Column("standing_minutes", sa.Integer(), nullable=False),
        sa.Column("total_steps", sa.Integer(), nullable=False),
        sa.Column("total_distance", sa.Float(), nullable=False),
        sa.Column("total_calories", sa.Float(), nullable=False),
        sa.UniqueConstraint("user_id", "summary_date", name="uq_summary_user_date"),
    )
    op.create_table(
        "model_predictions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("model_version_id", sa.String(36), sa.ForeignKey("model_versions.id", ondelete="SET NULL")),
        sa.Column("model_name", sa.String(80), nullable=False),
        sa.Column("predicted_activity", sa.String(16), nullable=False),
        sa.Column("confidence_score", sa.Float(), nullable=False),
        sa.Column("prediction_timestamp", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("predicted_activity IN ('Walking', 'Running', 'Sitting', 'Standing')", name="ck_prediction_activity"),
        sa.CheckConstraint("confidence_score >= 0 AND confidence_score <= 1", name="ck_prediction_confidence"),
    )
    op.create_index("ix_predictions_user_timestamp", "model_predictions", ["user_id", "prediction_timestamp"])
    op.create_table(
        "user_goals",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("daily_step_goal", sa.Integer(), nullable=False),
        sa.Column("weekly_running_goal", sa.Integer(), nullable=False),
        sa.Column("monthly_distance_goal", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", name="uq_user_goals_user_id"),
        sa.CheckConstraint("daily_step_goal > 0", name="ck_daily_step_goal_positive"),
        sa.CheckConstraint("weekly_running_goal >= 0", name="ck_weekly_running_goal_nonnegative"),
        sa.CheckConstraint("monthly_distance_goal >= 0", name="ck_monthly_distance_goal_nonnegative"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)


def downgrade() -> None:
    op.drop_table("user_goals")
    op.drop_index("ix_predictions_user_timestamp", table_name="model_predictions")
    op.drop_table("model_predictions")
    op.drop_table("daily_summary")
    op.drop_index("ix_steps_user_date", table_name="step_logs")
    op.drop_table("step_logs")
    op.drop_index("ix_activity_user_start", table_name="activity_logs")
    op.drop_table("activity_logs")
    op.drop_table("model_versions")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")