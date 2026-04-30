import os
from pathlib import Path

from dotenv import load_dotenv
from langchain_google_genai import GoogleGenerativeAIEmbeddings, ChatGoogleGenerativeAI
from langchain_community.vectorstores import Chroma
from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_classic.chains import ConversationalRetrievalChain
from langchain_classic.memory import ConversationBufferMemory

load_dotenv(dotenv_path=Path(__file__).resolve().parent / ".env")

# --- Config ---
CHROMA_DIR = "chroma_db"
CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200

# In-memory store: session_id -> ConversationalRetrievalChain
_chains: dict = {}
_embeddings = None
_llm = None


def _get_embeddings() -> GoogleGenerativeAIEmbeddings:
    global _embeddings
    if _embeddings is None:
        _embeddings = GoogleGenerativeAIEmbeddings(model="models/embedding-001")
    return _embeddings


def _get_llm() -> ChatGoogleGenerativeAI:
    global _llm
    if _llm is None:
        _llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash", temperature=0.3)
    return _llm


def ingest_pdf(file_path: str, session_id: str) -> int:
    """Load PDF, split into chunks, store in ChromaDB. Returns chunk count."""
    loader = PyPDFLoader(file_path)
    docs = loader.load()

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP
    )
    chunks = splitter.split_documents(docs)

    vectorstore = Chroma.from_documents(
        documents=chunks,
        embedding=_get_embeddings(),
        persist_directory=CHROMA_DIR,
        collection_name=session_id  # each session gets its own collection
    )
    vectorstore.persist()

    # Build chain for this session
    _chains[session_id] = _build_chain(vectorstore)

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
        except Exception:
            return "No document found for this session. Please upload a PDF first."

    chain = _chains[session_id]
    result = chain({"question": question})
    return result["answer"]


def _build_chain(vectorstore: Chroma) -> ConversationalRetrievalChain:
    """Build a ConversationalRetrievalChain with memory."""
    memory = ConversationBufferMemory(
        memory_key="chat_history",
        return_messages=True,
        output_key="answer"
    )
    retriever = vectorstore.as_retriever(search_kwargs={"k": 4})

    return ConversationalRetrievalChain.from_llm(
        llm=_get_llm(),
        retriever=retriever,
        memory=memory,
        return_source_documents=False,
        verbose=False
    )