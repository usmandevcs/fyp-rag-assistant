import os
import uuid
import shutil
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


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "8000")),
    )