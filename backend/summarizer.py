import json
import re

from langchain_chroma import Chroma

try:
    from backend.prompts import SUMMARY_PROMPT_TEMPLATE
except ImportError:
    from prompts import SUMMARY_PROMPT_TEMPLATE

try:
    from backend.rag_engine import CHROMA_DIR, _get_embeddings, _get_llm, _is_retryable_llm_error
except ImportError:
    from rag_engine import CHROMA_DIR, _get_embeddings, _get_llm, _is_retryable_llm_error


def generate_structured_summary(session_id: str) -> dict:
    """Generate a structured JSON summary of the document in the given session."""
    # Load the vectorstore for this session
    try:
        vectorstore = Chroma(
            persist_directory=CHROMA_DIR,
            embedding_function=_get_embeddings(),
            collection_name=session_id,
        )
    except Exception:
        raise ValueError(f"No document found for session '{session_id}'.")

    # Retrieve a broad set of representative chunks
    retriever = vectorstore.as_retriever(search_kwargs={"k": 10})
    docs = retriever.invoke("summarize the entire document")

    if not docs:
        raise ValueError("No document content found for this session.")

    # Build combined context from retrieved chunks
    combined_context = "\n\n---\n\n".join(doc.page_content for doc in docs)
    context = combined_context[:12000]

    prompt = SUMMARY_PROMPT_TEMPLATE.format(context=context)

    try:
        llm = _get_llm()
        response = llm.invoke(prompt)
        raw = response.content if hasattr(response, "content") else str(response)
    except Exception as e:
        if _is_retryable_llm_error(e):
            raise ValueError("Summary generation failed due to API limits. Please try again later.")
        raise

    # Clean up markdown formatting and extract JSON
    cleaned = raw.replace('```json', '').replace('```', '').strip()
    raw_output = cleaned

    try:
        try:
            parsed = json.loads(raw_output)
        except json.JSONDecodeError:
            match = re.search(r'\{[\s\S]*\}', raw_output)
            if match is None:
                raise
            parsed = json.loads(match.group(0))
    except Exception:
        return {
            "overview": raw_output[:500] + "...",
            "key_findings": ["Could not parse specific findings."],
            "critical_data_points": [],
            "conclusion": "Summary generated with partial data.",
        }

    summary_payload = {
        "overview": parsed.get("overview", parsed.get("Overview", "")),
        "key_findings": parsed.get("key_findings", parsed.get("Key Findings", [])),
        "critical_data_points": parsed.get(
            "critical_data_points", parsed.get("Critical Data Points", [])
        ),
        "conclusion": parsed.get("conclusion", parsed.get("Conclusion", "")),
    }

    if not summary_payload["overview"]:
        summary_payload["overview"] = "No data available"
    if not summary_payload["conclusion"]:
        summary_payload["conclusion"] = "No data available"
    if not isinstance(summary_payload["key_findings"], list):
        summary_payload["key_findings"] = []
    if not isinstance(summary_payload["critical_data_points"], list):
        summary_payload["critical_data_points"] = []

    return summary_payload
