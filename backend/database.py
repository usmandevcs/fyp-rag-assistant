"""Database models and initialization for RAG application."""

import os
from datetime import datetime
from sqlalchemy import create_engine, Column, String, DateTime, Integer, Text, ForeignKey, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship

# Database setup
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./rag_app.db")

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URL else {}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Session(Base):
    """Represents a PDF upload session."""
    __tablename__ = "sessions"

    id = Column(String(36), primary_key=True)  # UUID
    filename = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    chunk_count = Column(Integer, default=0)
    file_path = Column(String(512), nullable=True)
    is_active = Column(Boolean, default=True)

    # Relationships
    chat_history = relationship("ChatMessage", back_populates="session", cascade="all, delete-orphan")
    uploads = relationship("UploadedFile", back_populates="session", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Session(id={self.id}, filename={self.filename}, chunks={self.chunk_count})>"


class ChatMessage(Base):
    """Stores chat messages for a session."""
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(String(36), ForeignKey("sessions.id"), nullable=False)
    question = Column(Text, nullable=False)
    answer = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationship
    session = relationship("Session", back_populates="chat_history")

    def __repr__(self):
        return f"<ChatMessage(session_id={self.session_id}, question_len={len(self.question)})>"


class UploadedFile(Base):
    """Metadata about uploaded PDF files."""
    __tablename__ = "uploaded_files"

    id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(String(36), ForeignKey("sessions.id"), nullable=False)
    original_filename = Column(String(255), nullable=False)
    file_size_bytes = Column(Integer, nullable=True)
    upload_status = Column(String(50), default="pending")  # pending, completed, failed
    error_message = Column(Text, nullable=True)
    uploaded_at = Column(DateTime, default=datetime.utcnow)

    # Relationship
    session = relationship("Session", back_populates="uploads")

    def __repr__(self):
        return f"<UploadedFile(filename={self.original_filename}, status={self.upload_status})>"


def init_db():
    """Initialize database tables."""
    Base.metadata.create_all(bind=engine)


def get_db():
    """Get database session for dependency injection in FastAPI."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Initialize on import
init_db()
