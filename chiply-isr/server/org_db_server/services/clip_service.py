"""CLIP service for image-text embeddings using Sentence Transformers."""
import numpy as np
from typing import List, Union
from PIL import Image
from pathlib import Path
from sentence_transformers import SentenceTransformer

class CLIPService:
    """Service for generating image and text embeddings using CLIP via Sentence Transformers."""

    def __init__(self, model_name: str = "clip-ViT-B-32"):
        """Initialize with a CLIP model from Sentence Transformers."""
        self.model_name = model_name
        self.model = SentenceTransformer(model_name)
        # Get embedding dimension from the model
        self.dimension = self.model.get_sentence_embedding_dimension()

    def generate_text_embedding(self, text: str) -> np.ndarray:
        """Generate embedding for text."""
        embedding = self.model.encode(text, convert_to_numpy=True, normalize_embeddings=True)
        return embedding

    def generate_text_embeddings(self, texts: List[str]) -> List[np.ndarray]:
        """Generate embeddings for multiple texts."""
        embeddings = self.model.encode(texts, convert_to_numpy=True, normalize_embeddings=True)
        return [embeddings[i] for i in range(len(texts))]

    def generate_image_embedding(self, image_path: Union[str, Path]) -> np.ndarray:
        """Generate embedding for an image."""
        image = Image.open(image_path).convert("RGB")
        embedding = self.model.encode(image, convert_to_numpy=True, normalize_embeddings=True)
        return embedding

    def generate_image_embeddings(self, image_paths: List[Union[str, Path]]) -> List[np.ndarray]:
        """Generate embeddings for multiple images."""
        images = [Image.open(path).convert("RGB") for path in image_paths]
        embeddings = self.model.encode(images, convert_to_numpy=True, normalize_embeddings=True)
        return [embeddings[i] for i in range(len(images))]

    def similarity(self, emb1: np.ndarray, emb2: np.ndarray) -> float:
        """Calculate cosine similarity between two embeddings."""
        return float(np.dot(emb1, emb2) / (np.linalg.norm(emb1) * np.linalg.norm(emb2)))

# Global CLIP service instance (lazy loaded)
_clip_service = None

def get_clip_service(model_name: str = "clip-ViT-B-32") -> CLIPService:
    """Get or create the global CLIP service."""
    global _clip_service
    if _clip_service is None or _clip_service.model_name != model_name:
        _clip_service = CLIPService(model_name)
    return _clip_service
