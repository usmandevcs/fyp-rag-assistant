import os
import certifi

# This forces Python to bypass the Windows Certificate Store and use certifi
os.environ["SSL_CERT_FILE"] = certifi.where()

import uuid
import shutil
import tempfile
from typing import List
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from sqlalchemy.orm import Session as SQLSession
from langchain_chroma import Chroma
from langchain_core.documents import Document

try:
    from backend import rag_engine
    from backend.database import Session as DBSession, ChatMessage, UploadedFile, get_db
    from backend.summarizer import generate_structured_summary
    from backend.vision_utils import extract_images_from_pdf, generate_image_caption
except ImportError:
    import rag_engine
    from database import Session as DBSession, ChatMessage, UploadedFile, get_db
    from summarizer import generate_structured_summary
    from vision_utils import extract_images_from_pdf, generate_image_caption

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
    pinned_messages: list[str] = []


class ChatResponse(BaseModel):
    answer: str
    sources: List[str] = []
    follow_ups: List[str] = []
    chart_data: list | None = None


class VoiceChatResponse(BaseModel):
    question: str
    answer: str
    sources: List[str] = []
    follow_ups: List[str] = []
    chart_data: list | None = None


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


@app.get("/api/status")
async def api_status():
    """Retrieve the API key usage status for Groq and Gemini."""
    try:
        status = rag_engine.get_api_status()
        if "error" in status:
            raise HTTPException(status_code=500, detail=status["error"])
        return status
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get API status: {str(e)}")


@app.post("/upload")
async def upload_pdf(file: UploadFile = File(...), db: SQLSession = Depends(get_db)):
    """Upload a document (PDF, TXT, DOCX, XLSX) and get back a session_id for follow-up questions."""
    SUPPORTED_EXTENSIONS = (".pdf", ".txt", ".docx", ".xlsx")
    file_ext = os.path.splitext(file.filename)[1].lower() if file.filename else ""

    if file_ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Supported formats: {', '.join(SUPPORTED_EXTENSIONS)}",
        )

    session_id = str(uuid.uuid4())
    file_path = os.path.join(UPLOAD_DIR, f"{session_id}{file_ext}")

    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    chunk_count = rag_engine.ingest_file(file_path, session_id)

    # Extract images from PDF and add them as documents (PDF-only)
    if file_ext == ".pdf":
        try:
            images = extract_images_from_pdf(file_path)
            if images:
                image_documents = []
                for idx, image in enumerate(images):
                    try:
                        caption = generate_image_caption(image)
                        # Create a Document object for this image caption
                        image_doc = Document(
                            page_content=f"[Extracted Chart/Image Data]: {caption}",
                            metadata={
                                "source": file.filename,
                                "type": "image",
                                "image_index": idx
                            }
                        )
                        image_documents.append(image_doc)
                    except Exception as img_err:
                        print(f"Error generating caption for image {idx}: {img_err}")
                        continue
                
                # Add image documents to the same ChromaDB collection
                if image_documents:
                    try:
                        vectorstore = Chroma(
                            persist_directory="chroma_db",
                            embedding_function=rag_engine._get_embeddings(),
                            collection_name=session_id
                        )
                        vectorstore.add_documents(image_documents)
                        chunk_count += len(image_documents)
                    except Exception as db_err:
                        print(f"Warning: Failed to add image documents to ChromaDB: {db_err}")
        except Exception as e:
            print(f"Warning: Image extraction skipped: {e}")

    if chunk_count == 0:
        raise HTTPException(status_code=400, detail="No readable text or images found in the uploaded file.")

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
        "message": "File uploaded and indexed. You can now ask questions."
    }


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest, db: SQLSession = Depends(get_db)):
    """Ask a question about the uploaded document."""
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty.")

    result = rag_engine.ask_question(
        request.session_id,
        request.question,
        request.pinned_messages,
    )
    answer = result["answer"]
    sources = result.get("sources", [])
    follow_ups = result.get("follow_ups", [])
    chart_data = result.get("chart_data")
    
    # Store chat message in database
    chat_message = ChatMessage(
        session_id=request.session_id,
        question=request.question,
        answer=answer
    )
    db.add(chat_message)
    db.commit()
    
    return ChatResponse(answer=answer, sources=sources, follow_ups=follow_ups, chart_data=chart_data)


@app.post("/chat_voice", response_model=VoiceChatResponse)
async def chat_voice(
    session_id: str = File(...),
    audio: UploadFile = File(...),
    db: SQLSession = Depends(get_db),
):
    """Accept an audio file, transcribe it, and answer the question from the document."""
    if not session_id.strip():
        raise HTTPException(status_code=400, detail="session_id is required.")

    # Determine file suffix from the uploaded filename (e.g. .m4a, .wav, .webm)
    suffix = os.path.splitext(audio.filename or ".wav")[1] or ".wav"

    tmp_path = None
    try:
        # Save the uploaded audio to a temp file
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir=UPLOAD_DIR) as tmp:
            shutil.copyfileobj(audio.file, tmp)
            tmp_path = tmp.name

        # Transcribe the audio to text
        question = rag_engine.transcribe_audio(tmp_path)

        # Ask the RAG engine
        result = rag_engine.ask_question(session_id, question)
        answer = result["answer"]
        sources = result.get("sources", [])
        follow_ups = result.get("follow_ups", [])
        chart_data = result.get("chart_data")

        # Store chat message in database
        chat_message = ChatMessage(
            session_id=session_id,
            question=question,
            answer=answer,
        )
        db.add(chat_message)
        db.commit()

        return VoiceChatResponse(question=question, answer=answer, sources=sources, follow_ups=follow_ups, chart_data=chart_data)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Voice chat failed: {str(e)}"
        )
    finally:
        # Clean up temp file
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)



class MultiChatRequest(BaseModel):
    session_ids: List[str]
    question: str


@app.post("/chat_multi", response_model=ChatResponse)
def chat_multi(request: MultiChatRequest, db: SQLSession = Depends(get_db)):
    """Query multiple documents simultaneously and return a unified answer."""
    if not request.session_ids:
        raise HTTPException(status_code=400, detail="At least one session_id is required.")
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty.")

    try:
        result = rag_engine.ask_multiple_questions(
            request.session_ids,
            request.question,
            request.pinned_messages,
        )
        answer = result["answer"]
        sources = result.get("sources", [])
        follow_ups = result.get("follow_ups", [])
        chart_data = result.get("chart_data")

        # Store a chat record under the first session for history tracking
        chat_message = ChatMessage(
            session_id=request.session_ids[0],
            question=request.question,
            answer=answer,
        )
        db.add(chat_message)
        db.commit()

        return ChatResponse(answer=answer, sources=sources, follow_ups=follow_ups, chart_data=chart_data)
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Multi-document chat failed: {str(e)}"
        )


class SummaryResponse(BaseModel):
    overview: str = ""
    key_findings: List[str] = []
    critical_data_points: List[str] = []
    conclusion: str = ""


@app.get("/summary/{session_id}", response_model=SummaryResponse)
def get_structured_summary(session_id: str):
    """Generate a structured summary dashboard for the given document session."""
    try:
        result = generate_structured_summary(session_id)
        return SummaryResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Summary generation failed: {str(e)}"
        )


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
    """Process a YouTube, Web, or Google Drive URL and create a new session."""
    try:
        session_id = str(uuid.uuid4())

        # --- Google Drive link branch ---
        if "drive.google.com" in request.url:
            file_path = os.path.join(UPLOAD_DIR, f"{session_id}.pdf")
            rag_engine.download_drive_pdf(request.url, file_path)
            chunk_count = rag_engine.ingest_pdf(file_path, session_id)
            filename = "Drive Document"

            # Create database session record (same pattern as /upload)
            db_session = DBSession(
                id=session_id,
                filename=filename,
                chunk_count=chunk_count,
                file_path=file_path,
                is_active=True,
            )
            db.add(db_session)

            upload_record = UploadedFile(
                session_id=session_id,
                original_filename=filename,
                file_size_bytes=os.path.getsize(file_path),
                upload_status="completed",
            )
            db.add(upload_record)
            db.commit()

            return {
                "session_id": session_id,
                "filename": filename,
                "chunks_indexed": chunk_count,
                "message": "Google Drive PDF processed and indexed. You can now ask questions.",
            }

        # --- Existing YouTube / Web URL branch ---
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
    
    # ==========================================
    # Method 1: Localhost (Default)
    # This is the default method for local development and testing on the same machine.
    # If you're testing on a mobile device using ADB port forwarding, keep this method active

    uvicorn.run(
        app,
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "8000")),
    )

#     ==========================================
#     Method 2: Local Wi-Fi Network (Emergency)
#     ye physical mobile testing without ADB ky liye ha.
#     Comment out Method 1 above and uncomment the code below.
#     ==========================================
    # uvicorn.run(
    #     app,
    #     host=os.getenv("HOST", "0.0.0.0"), 
    #     port=int(os.getenv("PORT", "8000")),
    # )