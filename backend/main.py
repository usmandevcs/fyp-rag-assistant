import os
import uuid
import shutil
from typing import List
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from sqlalchemy.orm import Session as SQLSession

try:
    from backend import rag_engine
    from backend.database import Session as DBSession, ChatMessage, UploadedFile, get_db
except ImportError:
    import rag_engine
    from database import Session as DBSession, ChatMessage, UploadedFile, get_db

load_dotenv()

app = FastAPI(title="Document Summarizer & Q&A API", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = "temp_uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


class ChatRequest(BaseModel):
    session_id: str
    question: str


class ChatResponse(BaseModel):
    answer: str


class SessionResponseItem(BaseModel):
    session_id: str
    filename: str


class ChatHistoryItem(BaseModel):
    question: str
    answer: str


class UrlRequest(BaseModel):
    url: str


class TextRequest(BaseModel):
    text: str
    filename: str


@app.get("/")
def root():
    return {"status": "running", "message": "Document Q&A API is live."}


@app.post("/upload")
async def upload_pdf(file: UploadFile = File(...), db: SQLSession = Depends(get_db)):
    """Upload a PDF and get back a session_id for follow-up questions."""
    if not file.filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported.")

    session_id = str(uuid.uuid4())
    file_path = os.path.join(UPLOAD_DIR, f"{session_id}.pdf")

    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    chunk_count = rag_engine.ingest_pdf(file_path, session_id)

    # Create database session record
    db_session = DBSession(
        id=session_id,
        filename=file.filename,
        chunk_count=chunk_count,
        file_path=file_path,
        is_active=True
    )
    db.add(db_session)

    # Create upload metadata record
    upload_record = UploadedFile(
        session_id=session_id,
        original_filename=file.filename,
        file_size_bytes=file.size if hasattr(file, 'size') else None,
        upload_status="completed"
    )
    db.add(upload_record)
    db.commit()

    return {
        "session_id": session_id,
        "filename": file.filename,
        "chunks_indexed": chunk_count,
        "message": "PDF uploaded and indexed. You can now ask questions."
    }


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest, db: SQLSession = Depends(get_db)):
    """Ask a question about the uploaded document."""
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty.")

    answer = rag_engine.ask_question(request.session_id, request.question)
    
    # Store chat message in database
    chat_message = ChatMessage(
        session_id=request.session_id,
        question=request.question,
        answer=answer
    )
    db.add(chat_message)
    db.commit()
    
    return ChatResponse(answer=answer)


@app.get("/sessions", response_model=List[SessionResponseItem])
def get_sessions(db: SQLSession = Depends(get_db)):
    """Retrieve all sessions ordered by creation date (newest first)."""
    sessions = db.query(DBSession).order_by(DBSession.created_at.desc()).all()
    return [
        SessionResponseItem(session_id=session.id, filename=session.filename)
        for session in sessions
    ]


@app.get("/chat/{session_id}", response_model=List[ChatHistoryItem])
def get_chat_history(session_id: str, db: SQLSession = Depends(get_db)):
    """Retrieve chat history for a specific session ordered by creation date (oldest first)."""
    messages = db.query(ChatMessage).filter(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at.asc()).all()
    return [
        ChatHistoryItem(question=msg.question, answer=msg.answer)
        for msg in messages
    ]


@app.delete("/sessions/{session_id}")
def delete_session(session_id: str, db: SQLSession = Depends(get_db)):
    """Delete a session and its associated chat history."""
    session = db.query(DBSession).filter(DBSession.id == session_id).first()
    
    if not session:
        raise HTTPException(status_code=404, detail="Session not found.")
    
    db.delete(session)
    db.commit()
    
    return {"status": "success", "message": "Session deleted"}


@app.post("/process_url")
def process_url(request: UrlRequest, db: SQLSession = Depends(get_db)):
    """Process a YouTube or Web URL and create a new session."""
    try:
        session_id = str(uuid.uuid4())
        chunk_count = rag_engine.ingest_url(request.url, session_id)

        # Extract filename from URL or use a default
        filename = request.url.split("/")[-1][:50] or "Web Content"

        # Create database session record
        db_session = DBSession(
            id=session_id,
            filename=filename,
            chunk_count=chunk_count,
            file_path=request.url,
            is_active=True,
        )
        db.add(db_session)

        # Create metadata record
        url_record = UploadedFile(
            session_id=session_id,
            original_filename=filename,
            file_size_bytes=None,
            upload_status="completed",
        )
        db.add(url_record)
        db.commit()

        return {
            "session_id": session_id,
            "filename": filename,
            "chunks_indexed": chunk_count,
            "message": "URL processed and indexed. You can now ask questions.",
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to process URL: {str(e)}"
        )


@app.post("/process_text")
def process_text(request: TextRequest, db: SQLSession = Depends(get_db)):
    """Process raw text and create a new session."""
    try:
        session_id = str(uuid.uuid4())
        chunk_count = rag_engine.ingest_raw_text(request.text, session_id)

        # Create database session record
        db_session = DBSession(
            id=session_id,
            filename=request.filename,
            chunk_count=chunk_count,
            file_path=None,
            is_active=True,
        )
        db.add(db_session)

        # Create metadata record
        text_record = UploadedFile(
            session_id=session_id,
            original_filename=request.filename,
            file_size_bytes=len(request.text),
            upload_status="completed",
        )
        db.add(text_record)
        db.commit()

        return {
            "session_id": session_id,
            "filename": request.filename,
            "chunks_indexed": chunk_count,
            "message": "Text processed and indexed. You can now ask questions.",
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to process text: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "8000")),
    )

#     ==========================================
#     Method 2: Local Wi-Fi Network (Emergency)
#     For physical mobile testing without ADB.
#     Comment out Method 1 above and uncomment the code below.
#     ==========================================
#     uvicorn.run(
#         app,
#         host=os.getenv("HOST", "0.0.0.0"), 
#         port=int(os.getenv("PORT", "8000")),
#     )