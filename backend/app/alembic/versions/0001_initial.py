"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-01-01
"""
import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_users_email", "users", ["email"])

    op.create_table(
        "courses",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("color", sa.String(9), nullable=False, server_default="#4C6FFF"),
    )
    op.create_index("ix_courses_user_id", "courses", ["user_id"])

    op.create_table(
        "tasks",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("course_id", sa.Integer, sa.ForeignKey("courses.id", ondelete="SET NULL"), nullable=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("type", sa.String(20), nullable=False, server_default="assignment"),
        sa.Column("due_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("difficulty", sa.String(10), nullable=False, server_default="medium"),
        sa.Column("status", sa.String(20), nullable=False, server_default="not_started"),
        sa.Column("progress_pct", sa.Integer, nullable=False, server_default="0"),
    )
    op.create_index("ix_tasks_user_id", "tasks", ["user_id"])
    op.create_index("ix_tasks_course_id", "tasks", ["course_id"])

    op.create_table(
        "study_sessions",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("task_id", sa.Integer, sa.ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True),
        sa.Column("planned_start", sa.DateTime(timezone=True), nullable=True),
        sa.Column("planned_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("actual_duration", sa.Integer, nullable=True),
        sa.Column("completed", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("feedback", sa.String(10), nullable=True),
    )
    op.create_index("ix_study_sessions_user_id", "study_sessions", ["user_id"])

    op.create_table(
        "materials",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("course_id", sa.Integer, sa.ForeignKey("courses.id", ondelete="SET NULL"), nullable=True),
        sa.Column("filename", sa.String(255), nullable=False),
        sa.Column("file_url", sa.String(500), nullable=False),
        sa.Column("extracted_text", sa.Text, nullable=False, server_default=""),
        sa.Column("uploaded_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_materials_user_id", "materials", ["user_id"])

    op.create_table(
        "ai_generated",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("source_type", sa.String(20), nullable=False),
        sa.Column("source_id", sa.Integer, nullable=True),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("content_json", sa.Text, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_ai_generated_user_id", "ai_generated", ["user_id"])


def downgrade() -> None:
    for table in (
        "ai_generated",
        "materials",
        "study_sessions",
        "tasks",
        "courses",
        "users",
    ):
        op.drop_table(table)
