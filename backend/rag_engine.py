import os

from dotenv import load_dotenv
from langchain_chroma import Chroma
from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_classic.chains import ConversationalRetrievalChain
from langchain_groq import ChatGroq
from langchain_google_genai import GoogleGenerativeAIEmbeddings


load_dotenv()

# --- Config ---
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
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

# In-memory store: session_id -> ConversationalRetrievalChain
_chains: dict = {}
_chat_histories: dict = {}
_embeddings = None
_llm = None
_embedding_key_index = -1


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
        if not GROQ_API_KEY:
            raise ValueError("GROQ_API_KEY is not set.")
        _llm = ChatGroq(
            model_name="llama-3.3-70b-versatile",
            api_key=GROQ_API_KEY,
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
        raise ValueError("No readable text found in this PDF. Please upload a text-based PDF.")

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


def ask_question(session_id: str, question: str) -> str:
    """Ask a question against the session's document. Returns answer string."""
    if session_id not in _chains:
        # Try to reload from disk if server restarted
        try:
            vectorstore = Chroma(
                persist_directory=CHROMA_DIR,
                embedding_function=_get_embeddings(),
                collection_name=session_id
            )
            _chains[session_id] = _build_chain(vectorstore)
            _chat_histories.setdefault(session_id, [])
        except Exception:
            return "No document found for this session. Please upload a PDF first."

    chain = _chains[session_id]
    chat_history = _chat_histories.setdefault(session_id, [])
    try:
        result = chain.invoke({"question": question, "chat_history": chat_history})
        answer = result["answer"]
        chat_history.append((question, answer))
        return answer
    except Exception as first_error:
        if not _is_retryable_llm_error(first_error):
            raise

        return "Chat generation failed. Please try again later."


def _build_chain(vectorstore: Chroma) -> ConversationalRetrievalChain:
    """Build a ConversationalRetrievalChain."""
    retriever = vectorstore.as_retriever(search_kwargs={"k": 4})

    return ConversationalRetrievalChain.from_llm(
        llm=_get_llm(),
        retriever=retriever,
        return_source_documents=False,
        verbose=False
    )