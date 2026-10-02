"""add_auth_fields_to_users

Revision ID: e43384fc885c
Revises: 275c1f09ba43
Create Date: 2026-09-19 14:04:37.071258

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e43384fc885c'
down_revision: Union[str, Sequence[str], None] = '275c1f09ba43'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # La tabla ya puede tener el usuario demo. Necesitamos permitir NULL temporalmente
    # y luego añadir la restricción NOT NULL.
    op.add_column('users', sa.Column('email', sa.String(), nullable=True))
    op.add_column('users', sa.Column('password_hash', sa.String(), nullable=True))
    # Actualizar registros demo existentes para no romper la restricción
    op.execute("UPDATE users SET email = id || '@demo.lorica', password_hash = 'DEMO_HASH' WHERE email IS NULL")
    # Ahora sí aplicar NOT NULL y unique
    op.alter_column('users', 'email', nullable=False)
    op.alter_column('users', 'password_hash', nullable=False)
    op.create_unique_constraint('uq_users_email', 'users', ['email'])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint('uq_users_email', 'users', type_='unique')
    op.drop_column('users', 'password_hash')
    op.drop_column('users', 'email')
