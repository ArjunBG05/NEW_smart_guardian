from sqlalchemy import create_engine, Column, String, Integer, Text, DateTime, Enum, text
from sqlalchemy.orm import declarative_base
from dotenv import load_dotenv
import os
import enum

load_dotenv()

db_url = os.getenv("DB_URL")

if not db_url:
    raise RuntimeError("DB_URL is not set in .env")

engine = create_engine(db_url)

Base = declarative_base()


class UserRole(enum.Enum):
    patient = "patient"
    guardian = "guardian"


class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(100), nullable=False, unique=True)
    password_hash = Column(Text, nullable=False)
    user_role = Column(Enum(UserRole), nullable=False)
    is_active = Column(Integer, nullable=False, server_default=text("1"))
    created_at = Column(DateTime, server_default=text("CURRENT_TIMESTAMP"))