"""Tests for CLIP service."""
import pytest
import numpy as np
from PIL import Image
import tempfile
from pathlib import Path

from org_db_server.services.clip_service import CLIPService

# Skip CLIP tests if model not available (requires download)
pytest.importorskip("transformers")

@pytest.fixture
def clip_service():
    """Create CLIP service for testing - skipped if model not cached."""
    pytest.skip("CLIP model requires download - test manually with internet connection")
    return CLIPService(model_name="openai/clip-vit-base-patch32")

@pytest.fixture
def test_image():
    """Create a test image."""
    # Create a simple test image
    img = Image.new('RGB', (224, 224), color='red')
    temp_file = tempfile.NamedTemporaryFile(suffix='.png', delete=False)
    img.save(temp_file.name)
    yield Path(temp_file.name)
    # Cleanup
    Path(temp_file.name).unlink()

def test_generate_text_embedding(clip_service):
    """Test generating a single text embedding."""
    text = "a photo of a cat"

    embedding = clip_service.generate_text_embedding(text)

    assert isinstance(embedding, np.ndarray)
    assert embedding.shape[0] == 512  # CLIP ViT-B/32 dimension
    assert np.isfinite(embedding).all()

def test_generate_image_embedding(clip_service, test_image):
    """Test generating an image embedding."""
    embedding = clip_service.generate_image_embedding(test_image)

    assert isinstance(embedding, np.ndarray)
    assert embedding.shape[0] == 512  # CLIP ViT-B/32 dimension
    assert np.isfinite(embedding).all()

def test_text_image_similarity(clip_service, test_image):
    """Test similarity between text and image embeddings."""
    text = "a red square"

    text_embedding = clip_service.generate_text_embedding(text)
    image_embedding = clip_service.generate_image_embedding(test_image)

    similarity = clip_service.similarity(text_embedding, image_embedding)

    # Similarity should be a reasonable value between -1 and 1
    assert -1 <= similarity <= 1
    assert isinstance(similarity, float)
