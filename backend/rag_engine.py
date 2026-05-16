import os
import json
import re
import tempfile
import gdown

from dotenv import load_dotenv
from langchain_chroma import Chroma
from langchain_community.document_loaders import (
    PyPDFLoader,
    YoutubeLoader,
    TextLoader,
    Docx2txtLoader,
    UnstructuredExcelLoader,
)
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_classic.chains import ConversationalRetrievalChain
from langchain_groq import ChatGroq
from langchain_google_genai import GoogleGenerativeAIEmbeddings
import yt_dlp
from groq import Groq
import trafilatura

try:
    from backend.prompts import CHAT_SYSTEM_TEMPLATE, MULTI_CHAT_PROMPT_TEMPLATE
except ImportError:
    from prompts import CHAT_SYSTEM_TEMPLATE, MULTI_CHAT_PROMPT_TEMPLATE


load_dotenv()

# --- Config --- #
CHROMA_DIR = "chroma_db"
CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200
REQUEST_TIMEOUT_SECONDS = 20

GOOGLE_API_KEYS = [
    key.strip()
    for key in (
        os.getenv("GOOGLE_API_KEYS")
        or os.getenv("GOOGLE_API_KEY", "")
    ).replace(";", ",").replace("\n", ",").split(",")
    if key.strip()
]
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GROQ_API_KEYS = [
    key.strip()
    for key in (
        os.getenv("GROQ_API_KEYS")
        or os.getenv("GROQ_API_KEY", "")
    ).replace(";", ",").replace("\n", ",").split(",")
    if key.strip()
]

# In-memory store: session_id -> ConversationalRetrievalChain
_chains: dict = {}
_chat_histories: dict = {}
_embeddings = None
_llm = None
_embedding_key_index = -1
_groq_key_index = -1
_groq_requests_count = 0


class ChromaSafeGoogleEmbeddings(GoogleGenerativeAIEmbeddings):
    def embed_documents(
        self,
        texts: list[str],
        *,
        batch_size: int = 100,
        task_type: str | None = None,
        titles: list[str] | None = None,
        output_dimensionality: int | None = None,
    ) -> list[list[float]]:
        embeddings = []
        for index, text in enumerate(texts):
            title = titles[index] if titles and index < len(titles) else None
            document_embeddings = super().embed_documents(
                [text],
                batch_size=1,
                task_type=task_type,
                titles=[title] if title is not None else None,
                output_dimensionality=output_dimensionality,
            )
            embeddings.append(document_embeddings[0])
        return embeddings


def get_random_google_key() -> str:
    return _get_next_embedding_key()


def _get_next_embedding_key() -> str:
    global _embedding_key_index
    if not GOOGLE_API_KEYS:
        raise ValueError("GOOGLE_API_KEYS is empty. Provide at least one Google API key.")

    _embedding_key_index = (_embedding_key_index + 1) % len(GOOGLE_API_KEYS)
    return GOOGLE_API_KEYS[_embedding_key_index]



def _get_next_groq_key() -> str:
    global _groq_key_index
    if not GROQ_API_KEYS:
        raise ValueError("GROQ_API_KEYS is empty. Provide at least one Groq API key.")

    _groq_key_index = (_groq_key_index + 1) % len(GROQ_API_KEYS)
    return GROQ_API_KEYS[_groq_key_index]


def transcribe_audio(file_path: str) -> str:
    """Transcribe an audio file using Groq Whisper. Returns the transcribed text."""
    if not GROQ_API_KEYS:
        raise ValueError("GROQ_API_KEYS is empty. Provide at least one Groq API key.")

    last_error: Exception | None = None
    for _ in range(min(len(GROQ_API_KEYS), 3)):
        try:
            client = Groq(api_key=_get_next_groq_key())
            with open(file_path, "rb") as audio_file:
                transcription = client.audio.transcriptions.create(
                    file=audio_file,
                    model="whisper-large-v3",
                    language="en",
                )
            text = transcription.text if hasattr(transcription, "text") else str(transcription)
            if not text or not text.strip():
                raise ValueError("Transcription returned empty text.")
            return text.strip()
        except Exception as e:
            last_error = e
            if not _is_quota_error(e):
                raise

    raise ValueError(
        f"Audio transcription failed after retrying with available Groq keys: {last_error}"
    )


def get_api_status() -> dict:
    """Returns the current API key usage status."""
    try:
        groq_total = len(GROQ_API_KEYS)
        groq_active = max(0, _groq_key_index)
        
        # Calculate dynamic usage based on tracking counter with a mock limit of 100
        groq_usage = round((_groq_requests_count / 100) * 100)

        google_total = len(GOOGLE_API_KEYS)
        google_active = max(0, _embedding_key_index)
        google_usage = round((google_active / max(1, google_total)) * 100)

        return {
            "groq_status": "Healthy" if groq_total > 0 else "Offline",
            "groq_active_key": groq_active,
            "groq_total_keys": groq_total,
            "groq_usage_percent": groq_usage,
            "google_status": "Healthy" if google_total > 0 else "Offline",
            "google_active_key": google_active,
            "google_total_keys": google_total,
            "google_usage_percent": google_usage,
        }
    except Exception as e:
        return {"error": str(e)}


def _get_embeddings() -> GoogleGenerativeAIEmbeddings:
    global _embeddings
    if _embeddings is None:
        current_google_key = _get_next_embedding_key()
        _embeddings = ChromaSafeGoogleEmbeddings(
            model="gemini-embedding-2-preview",
            google_api_key=current_google_key,
            request_timeout=REQUEST_TIMEOUT_SECONDS,
        )
    return _embeddings


def _reset_embeddings() -> None:
    global _embeddings
    _embeddings = None


def _get_llm() -> ChatGroq:
    global _llm
    if _llm is None:
        if not GROQ_API_KEYS:
            raise ValueError("GROQ_API_KEYS is not set. Provide at least one Groq API key.")
        _llm = ChatGroq(
            model_name="llama-3.3-70b-versatile",
            api_key=_get_next_groq_key(),
            temperature=0.7,
        )
    return _llm


def _is_quota_error(error: Exception) -> bool:
    message = str(error)
    return "RESOURCE_EXHAUSTED" in message or "429" in message or "quota" in message.lower()


def _is_retryable_llm_error(error: Exception) -> bool:
    message = str(error)
    return (
        _is_quota_error(error)
        or "NOT_FOUND" in message
        or "404" in message
        or "generateContent" in message
    )


def _rebuild_chain_for_session(session_id: str) -> None:
    vectorstore = Chroma(
        persist_directory=CHROMA_DIR,
        embedding_function=_get_embeddings(),
        collection_name=session_id,
    )
    _chains[session_id] = _build_chain(vectorstore)


def download_drive_pdf(url: str, output_path: str) -> str:
    """Download a PDF from a Google Drive share link using gdown.

    Args:
        url: Any Google Drive file URL (share link, direct link, etc.).
        output_path: Full local path where the downloaded file should be saved.

    Returns:
        The path to the downloaded file.

    Raises:
        ValueError: If the download fails or the URL is not accessible.
    """
    try:
        result = gdown.download(url, output_path, quiet=False)
    except Exception as exc:
        raise ValueError(
            f"Failed to download from Google Drive: {exc}"
        ) from exc

    if result is None or not os.path.exists(output_path):
        raise ValueError(
            "Could not download the file from Google Drive. "
            "Make sure the link is publicly shared."
        )

    return output_path


def ingest_pdf(file_path: str, session_id: str) -> int:
    """Load PDF, split into chunks, store in ChromaDB. Returns chunk count."""
    loader = PyPDFLoader(file_path)
    docs = loader.load()

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP
    )
    chunks = splitter.split_documents(docs)

    # Filter out empty or whitespace-only chunks to avoid embedding/indexing errors
    valid_chunks = [chunk for chunk in chunks if chunk.page_content and chunk.page_content.strip()]
    if not valid_chunks:
        return 0

    vectorstore = None
    for _ in range(2):
        try:
            vectorstore = Chroma.from_documents(
                documents=valid_chunks,
                embedding=_get_embeddings(),
                persist_directory=CHROMA_DIR,
                collection_name=session_id  # each session gets its own collection
            )
            break
        except Exception as embed_error:
            if not _is_quota_error(embed_error):
                raise
            _reset_embeddings()

    if vectorstore is None:
        raise ValueError("Google API quota exceeded for embeddings. Please add a billed key or try again later.")

    # Build chain for this session
    _chains[session_id] = _build_chain(vectorstore)
    _chat_histories[session_id] = []

    return len(chunks)


def ingest_file(file_path: str, session_id: str) -> int:
    """Load a file (.pdf, .txt, .docx, .xlsx), split into chunks, store in ChromaDB. Returns chunk count."""
    ext = os.path.splitext(file_path)[1].lower()

    if ext == ".pdf":
        return ingest_pdf(file_path, session_id)
    elif ext == ".txt":
        loader = TextLoader(file_path, encoding="utf-8")
    elif ext == ".docx":
        loader = Docx2txtLoader(file_path)
    elif ext == ".xlsx":
        loader = UnstructuredExcelLoader(file_path, mode="elements")
    else:
        raise ValueError(f"Unsupported file type: {ext}")

    docs = loader.load()

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP,
    )
    chunks = splitter.split_documents(docs)

    # Filter out empty or whitespace-only chunks
    valid_chunks = [chunk for chunk in chunks if chunk.page_content and chunk.page_content.strip()]
    if not valid_chunks:
        return 0

    vectorstore = None
    for _ in range(2):
        try:
            vectorstore = Chroma.from_documents(
                documents=valid_chunks,
                embedding=_get_embeddings(),
                persist_directory=CHROMA_DIR,
                collection_name=session_id,
            )
            break
        except Exception as embed_error:
            if not _is_quota_error(embed_error):
                raise
            _reset_embeddings()

    if vectorstore is None:
        raise ValueError("Google API quota exceeded for embeddings. Please add a billed key or try again later.")

    # Build chain for this session
    _chains[session_id] = _build_chain(vectorstore)
    _chat_histories[session_id] = []

    return len(chunks)


def ingest_url(url: str, session_id: str) -> int:
    """Load content from YouTube or Web URL, split into chunks, store in ChromaDB. Returns chunk count."""
    docs = []

    # Check if it's a YouTube URL
    if "youtube.com" in url or "youtu.be" in url:
        try:
            loader = YoutubeLoader.from_youtube_url(url, add_video_info=False)
            docs = loader.load()
        except Exception as e:
            try:
                with tempfile.TemporaryDirectory() as temp_dir:
                    ydl_opts = {
                        "format": "worstaudio[ext=m4a]/worstaudio/worst",
                        "outtmpl": os.path.join(temp_dir, "%(title)s.%(ext)s"),
                        "noplaylist": True,
                        "quiet": True,
                        "no_warnings": True,
                    }

                    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                        info = ydl.extract_info(url, download=True)
                        downloaded_file = ydl.prepare_filename(info)

                    if not os.path.exists(downloaded_file):
                        matches = [
                            os.path.join(temp_dir, name)
                            for name in os.listdir(temp_dir)
                        ]
                        if not matches:
                            raise FileNotFoundError("Downloaded audio file was not found.")
                        downloaded_file = matches[0]

                    client = Groq(api_key=_get_next_groq_key())
                    with open(downloaded_file, "rb") as audio_file:
                        transcription = client.audio.transcriptions.create(
                            file=audio_file,
                            model="whisper-large-v3",
                            language="en",
                        )

                    transcribed_text = transcription.text if hasattr(transcription, "text") else str(transcription)
                    docs = [
                        Document(
                            page_content=transcribed_text,
                            metadata={"source": url, "transcription_model": "whisper-large-v3"},
                        )
                    ]
            except Exception as fallback_error:
                raise ValueError(
                    "Could not extract transcript from captions, and audio transcription fallback also failed."
                ) from fallback_error
    else:
        # Treat as a web URL; use trafilatura for clean extraction
        try:
            downloaded = trafilatura.fetch_url(url)
            if downloaded is None:
                raise ValueError("Could not fetch the provided website.")

            text = trafilatura.extract(downloaded)
            if text is None or text.strip() == "":
                raise ValueError("Could not extract text from the provided website.")

            docs = [Document(page_content=text)]
        except ValueError:
            raise
        except Exception as e:
            raise ValueError(f"Failed to process URL: {str(e)}") from e

    if not docs:
        raise ValueError("No content extracted from the provided URL.")

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE, chunk_overlap=CHUNK_OVERLAP
    )
    chunks = splitter.split_documents(docs)

    # Filter out empty or whitespace-only chunks
    valid_chunks = [
        chunk
        for chunk in chunks
        if chunk.page_content and chunk.page_content.strip()
    ]
    if not valid_chunks:
        raise ValueError("No readable text found in the provided URL content.")

    vectorstore = None
    for _ in range(2):
        try:
            vectorstore = Chroma.from_documents(
                documents=valid_chunks,
                embedding=_get_embeddings(),
                persist_directory=CHROMA_DIR,
                collection_name=session_id,
            )
            break
        except Exception as embed_error:
            if not _is_quota_error(embed_error):
                raise
            _reset_embeddings()

    if vectorstore is None:
        raise ValueError(
            "Google API quota exceeded for embeddings. Please add a billed key or try again later."
        )

    # Build chain for this session
    _chains[session_id] = _build_chain(vectorstore)
    _chat_histories[session_id] = []

    return len(chunks)


def ingest_raw_text(text: str, session_id: str) -> int:
    """Ingest raw text, split into chunks, store in ChromaDB. Returns chunk count."""
    if not text or text.strip() == "":
        raise ValueError("Raw text cannot be empty.")

    docs = [Document(page_content=text)]

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE, chunk_overlap=CHUNK_OVERLAP
    )
    chunks = splitter.split_documents(docs)

    # Filter out empty or whitespace-only chunks
    valid_chunks = [
        chunk
        for chunk in chunks
        if chunk.page_content and chunk.page_content.strip()
    ]
    if not valid_chunks:
        raise ValueError("No readable text found in the provided content.")

    vectorstore = None
    for _ in range(2):
        try:
            vectorstore = Chroma.from_documents(
                documents=valid_chunks,
                embedding=_get_embeddings(),
                persist_directory=CHROMA_DIR,
                collection_name=session_id,
            )
            break
        except Exception as embed_error:
            if not _is_quota_error(embed_error):
                raise
            _reset_embeddings()

    if vectorstore is None:
        raise ValueError(
            "Google API quota exceeded for embeddings. Please add a billed key or try again later."
        )

    # Build chain for this session
    _chains[session_id] = _build_chain(vectorstore)
    _chat_histories[session_id] = []

    return len(chunks)


def _fallback_extract_answer_followups(text: str) -> tuple[str, list[str], list | None] | None:
    """If full JSON parse fails, pull ``answer`` and ``follow_ups`` using ``JSONDecoder`` / regex heuristics."""
    dec = json.JSONDecoder()
    brace_start = text.find("{")
    if brace_start != -1:
        try:
            obj, _ = dec.raw_decode(text, brace_start)
            if isinstance(obj, dict):
                ans = obj.get("answer")
                if ans is not None:
                    if not isinstance(ans, str):
                        ans = str(ans)
                    fu = obj.get("follow_ups", [])
                    if not isinstance(fu, list):
                        fu = []
                    cd = obj.get("chart_data")
                    if not isinstance(cd, list):
                        cd = None
                    return ans, [str(x) for x in fu], cd
        except json.JSONDecodeError:
            pass

    m = re.search(r'"answer"\s*:\s*', text)
    if not m:
        return None
    pos = m.end()
    try:
        answer, _ = dec.raw_decode(text, pos)
        if not isinstance(answer, str):
            answer = str(answer)
    except json.JSONDecodeError:
        rel = text[pos:].lstrip()
        if not rel.startswith('"'):
            return None
        bm = re.search(r'"\s*,\s*"follow_ups"', rel)
        if not bm:
            return None
        inner = rel[1 : bm.start()]
        try:
            answer = json.loads('"' + inner + '"')
        except json.JSONDecodeError:
            answer = inner.replace("\\n", "\n")

    follow_ups: list[str] = []
    fm = re.search(r'"follow_ups"\s*:\s*', text)
    if fm:
        fpos = fm.end()
        try:
            raw_list, _ = dec.raw_decode(text, fpos)
            if isinstance(raw_list, list):
                follow_ups = [str(x) for x in raw_list]
        except json.JSONDecodeError:
            pass

    chart_data = None
    cm = re.search(r'"chart_data"\s*:\s*', text)
    if cm:
        cpos = cm.end()
        try:
            raw_list, _ = dec.raw_decode(text, cpos)
            if isinstance(raw_list, list):
                chart_data = raw_list
        except json.JSONDecodeError:
            pass

    return answer, follow_ups, chart_data


def _parse_chat_json(raw_text: str) -> tuple[str, list[str], list | None]:
    """Parse JSON response from the LLM; clean aggressively, then fall back so callers never see a JSON parse error string."""
    raw_output = raw_text.replace("```json", "").replace("```", "").strip()
    cleaned_output = raw_output.replace("'\n|", "\n|").replace("|\n'", "|\n")
    table_fixed = cleaned_output
    cleaned_output = cleaned_output.replace("\n", "\\n")

    parsed = None
    for candidate in (cleaned_output, table_fixed, raw_output):
        try:
            parsed = json.loads(candidate, strict=False)
            break
        except json.JSONDecodeError:
            continue

    if parsed is None:
        for blob_src in (cleaned_output, table_fixed, raw_output):
            json_match = re.search(r"\{[\s\S]*\}", blob_src)
            if json_match:
                try:
                    parsed = json.loads(json_match.group(0), strict=False)
                    break
                except json.JSONDecodeError:
                    continue

    if parsed is not None and isinstance(parsed, dict):
        ans = parsed.get("answer")
        if ans is None:
            for src in (cleaned_output, table_fixed, raw_output):
                fb = _fallback_extract_answer_followups(src)
                if fb is not None:
                    return fb
            return "", [], None
        if not isinstance(ans, str):
            ans = str(ans)
        follow_ups = parsed.get("follow_ups", [])
        if not isinstance(follow_ups, list):
            follow_ups = []
        follow_ups = [str(x) for x in follow_ups]
        chart_data = parsed.get("chart_data")
        if not isinstance(chart_data, list):
            chart_data = None
        return ans, follow_ups, chart_data

    fb = _fallback_extract_answer_followups(cleaned_output)
    if fb is not None:
        return fb
    fb = _fallback_extract_answer_followups(table_fixed)
    if fb is not None:
        return fb
    fb = _fallback_extract_answer_followups(raw_output)
    if fb is not None:
        return fb

    return "", [], None

def ask_question(session_id: str, question: str, pinned_messages: list[str] = None) -> dict:
    """Ask a question against the session's document. Returns dict with 'answer' and 'sources'."""
    chain_key = session_id
    if chain_key not in _chains:
        # Try to reload from disk if server restarted
        try:
            vectorstore = Chroma(
                persist_directory=CHROMA_DIR,
                embedding_function=_get_embeddings(),
                collection_name=session_id
            )
            _chains[chain_key] = _build_chain(vectorstore)
            _chat_histories.setdefault(session_id, [])
        except Exception:
            return {"answer": "No document found for this session. Please upload a PDF first.", "sources": []}

    chain = _chains[chain_key]
    chat_history = _chat_histories.setdefault(session_id, [])
    try:
        result = chain.invoke(
            {
                "question": question,
                "chat_history": chat_history,
                "pinned_context": _get_pinned_context(pinned_messages),
            }
        )
        
        global _groq_requests_count
        _groq_requests_count += 1
        
        raw_answer = result["answer"]
        answer, follow_ups, chart_data = _parse_chat_json(raw_answer)
        chat_history.append((question, answer))

        # Extract unique sources from returned source documents
        sources = []
        seen = set()
        for doc in result.get("source_documents", []):
            meta = doc.metadata or {}
            if "page" in meta:
                label = f"Page {int(meta['page']) + 1}"
            elif "source" in meta:
                label = meta["source"]
            else:
                continue
            if label not in seen:
                seen.add(label)
                sources.append(label)

        return {"answer": answer, "sources": sources, "follow_ups": follow_ups, "chart_data": chart_data}
    except Exception as first_error:
        if not _is_retryable_llm_error(first_error):
            raise

        return {"answer": "Chat generation failed. Please try again later.", "sources": []}


def ask_multiple_questions(
    session_ids: list[str], question: str, pinned_messages: list[str] = None
) -> dict:
    """Query multiple document sessions simultaneously and return a unified answer."""
    if not session_ids:
        return {"answer": "No session IDs provided.", "sources": []}
    if not question or not question.strip():
        return {"answer": "Question cannot be empty.", "sources": []}

    all_docs = []
    for sid in session_ids:
        try:
            vectorstore = Chroma(
                persist_directory=CHROMA_DIR,
                embedding_function=_get_embeddings(),
                collection_name=sid,
            )
            retriever = vectorstore.as_retriever(search_kwargs={"k": 2})
            docs = retriever.invoke(question)
            all_docs.extend(docs)
        except Exception:
            # Skip sessions whose collection can't be loaded (deleted, etc.)
            continue

    if not all_docs:
        return {
            "answer": "No relevant content found in the selected documents.",
            "sources": [],
        }

    # Build combined context string
    context_parts = []
    for doc in all_docs:
        context_parts.append(doc.page_content)

    combined_context = "\n\n---\n\n".join(context_parts)

    pinned_context = _get_pinned_context(pinned_messages)

    # Build the prompt
    prompt = MULTI_CHAT_PROMPT_TEMPLATE.format(
        pinned_context=pinned_context,
        combined_context=combined_context,
        question=question,
    )

    # Generate answer using the shared LLM
    try:
        llm = _get_llm()
        response = llm.invoke(prompt)
        raw_answer = response.content if hasattr(response, "content") else str(response)
        answer, follow_ups, chart_data = _parse_chat_json(raw_answer)
    except Exception as e:
        if _is_retryable_llm_error(e):
            return {"answer": "Chat generation failed. Please try again later.", "sources": [], "follow_ups": [], "chart_data": None}
        raise

    # Extract unique source labels
    sources = []
    seen: set[str] = set()
    for doc in all_docs:
        meta = doc.metadata or {}
        if "page" in meta:
            label = f"Page {int(meta['page']) + 1}"
        elif "source" in meta:
            label = meta["source"]
        else:
            continue
        if label not in seen:
            seen.add(label)
            sources.append(label)

    return {"answer": answer, "sources": sources, "follow_ups": follow_ups, "chart_data": chart_data}


try:
    from backend.summarizer import generate_structured_summary
except ImportError:
    from summarizer import generate_structured_summary


def _get_prompt():
    from langchain_core.prompts import (
        ChatPromptTemplate,
        HumanMessagePromptTemplate,
        SystemMessagePromptTemplate,
    )

    system_template = CHAT_SYSTEM_TEMPLATE

    messages = [
        SystemMessagePromptTemplate.from_template(system_template),
        HumanMessagePromptTemplate.from_template("{question}"),
    ]
    return ChatPromptTemplate.from_messages(messages)


def _get_pinned_context(pinned_messages: list[str] | None) -> str:
    if pinned_messages:
        return "\n".join(pinned_messages)
    return "No pinned facts."


def _build_chain(vectorstore: Chroma) -> ConversationalRetrievalChain:
    """Build a ConversationalRetrievalChain."""
    retriever = vectorstore.as_retriever(search_kwargs={"k": 4})
    
    prompt = _get_prompt()

    return ConversationalRetrievalChain.from_llm(
        llm=_get_llm(),
        retriever=retriever,
        return_source_documents=True,
        combine_docs_chain_kwargs={"prompt": prompt},
        verbose=False
    )