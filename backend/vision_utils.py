import io
import os

import fitz
from PIL import Image
from google import genai


def _get_gemini_api_key() -> str | None:
    raw_keys = os.getenv("GOOGLE_API_KEYS") or os.getenv("GOOGLE_API_KEY", "")
    keys = [
        key.strip()
        for key in raw_keys.replace(";", ",").replace("\n", ",").split(",")
        if key.strip()
    ]
    return keys[0] if keys else None


GEMINI_API_KEY = _get_gemini_api_key()
GEMINI_CLIENT = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None


def extract_images_from_pdf(pdf_path: str) -> list[Image.Image]:
    """
    Extract all images from a PDF file.
    
    Args:
        pdf_path: Path to the PDF file.
        
    Returns:
        A list of PIL Image objects extracted from the PDF.
    """
    images = []
    
    try:
        pdf_document = fitz.open(pdf_path)
    except Exception as e:
        print(f"Error opening PDF at {pdf_path}: {e}")
        return images
    
    try:
        # Iterate through all pages in the PDF
        for page_num in range(len(pdf_document)):
            try:
                page = pdf_document[page_num]
                
                # Get all images on this page
                image_list = page.get_images(full=True)
                
                for image_index, img_info in enumerate(image_list):
                    try:
                        # Extract the image
                        xref = img_info[0]
                        pix = fitz.Pixmap(pdf_document, xref)
                        
                        # Convert to RGB if necessary (handle CMYK, grayscale, etc.)
                        if pix.n - pix.alpha < 4:
                            # Grayscale or RGB
                            img_data = pix.tobytes("ppm")
                        else:
                            # CMYK or other; convert to RGB
                            pix = fitz.Pixmap(fitz.csRGB, pix)
                            img_data = pix.tobytes("ppm")
                        
                        # Convert bytes to PIL Image
                        pil_image = Image.open(io.BytesIO(img_data))
                        images.append(pil_image)
                        
                    except Exception as img_err:
                        print(f"Warning: Failed to extract image {image_index} from page {page_num}: {img_err}")
                        continue
                        
            except Exception as page_err:
                print(f"Warning: Error processing page {page_num}: {page_err}")
                continue
                
    finally:
        pdf_document.close()
    
    return images


def generate_image_caption(image: Image.Image) -> str:
    """
    Generate a detailed text description of an image using Gemini Vision API.
    
    Args:
        image: A PIL Image object to describe.
        
    Returns:
        A detailed text description of the image.
    """
    if not GEMINI_CLIENT:
        return "Error: Gemini API key not configured."
    
    try:
        # Convert PIL Image to bytes for the API
        image_bytes = io.BytesIO()
        image.save(image_bytes, format="PNG")
        image_bytes.seek(0)
        
        # Create the prompt for detailed image description
        prompt = (
            "Describe this image, graph, or chart in extreme detail. "
            "Include all visible numbers, labels, axes, and key trends. "
            "If it's just a decorative image, return 'Decorative image'."
        )
        
        # Send the image to the model using the new google-genai SDK
        response = GEMINI_CLIENT.models.generate_content(
            model="gemini-1.5-flash",
            contents=[
                prompt,
                {
                    "mime_type": "image/png",
                    "data": image_bytes.getvalue(),
                },
            ]
        )
        
        return response.text
        
    except Exception as e:
        print(f"Error generating image caption: {e}")
        return f"Error: Could not generate caption ({str(e)})"