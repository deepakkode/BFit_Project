"""Normalize user emails and enforce case-insensitive uniqueness.

Revision ID: 0002_email_ci
Revises: 0001_initial
"""
from alembic import op
import sqlalchemy as sa

revision = "0002_email_ci"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
    DO $$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM users
            GROUP BY lower(trim(email))
            HAVING count(*) > 1
        ) THEN
            RAISE EXCEPTION 'Duplicate emails differ only by case or surrounding whitespace; resolve them before migration';
        END IF;
    END $$;
    """)
    op.execute("UPDATE users SET email = lower(trim(email))")
    op.drop_index("ix_users_email", table_name="users")
    op.create_index("uq_users_email_ci", "users", [sa.text("lower(email)")], unique=True)


def downgrade() -> None:
    op.drop_index("uq_users_email_ci", table_name="users")
    op.create_index("ix_users_email", "users", ["email"], unique=True)