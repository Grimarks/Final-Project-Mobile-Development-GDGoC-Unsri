"""index email users jadi unique (sesuai model)

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-06
"""
from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # keunikan email udah dijaga constraint kolom, ini cuma nyamain index-nya sama
    # model biar `alembic check` bersih
    op.drop_index("ix_users_email", table_name="users")
    op.create_index("ix_users_email", "users", ["email"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_users_email", table_name="users")
    op.create_index("ix_users_email", "users", ["email"])
