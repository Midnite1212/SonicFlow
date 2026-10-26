"""HTTP routes for browsing, downloading, adding, and removing models."""

import json
from pathlib import Path
from typing import TYPE_CHECKING

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from sonicflow.downloads import Downloads, remove_download
from sonicflow.models import (
    FAMILY_KIND,
    Model,
    all_models,
    custom_id,
    family_from_config,
    find,
    folder_family,
    folder_size,
    is_installed,
    load_custom,
    save_custom,
)

if TYPE_CHECKING:
    from sonicflow.server import Engine


class ModelRef(BaseModel):
    id: str


class NewModel(BaseModel):
    source: str
    title: str | None = None


def inspect_hub_repo(repo: str) -> tuple[str, int]:
    """Family and size of a Hugging Face repo, refusing anything that is not an MLX model."""
    from huggingface_hub import HfApi, hf_hub_download

    info = HfApi().model_info(repo, files_metadata=True)
    config = json.loads(Path(hf_hub_download(repo, "config.json")).read_text())
    family = family_from_config(config)
    tags = set(info.tags or [])
    is_mlx = info.library_name == "mlx" or "mlx" in tags or family in ("whisper", "parakeet")
    if config.get("model_type") == "whisper" and family != "whisper":
        raise ValueError(
            "this is a PyTorch Whisper model; use an MLX build (mlx-community/whisper-*-mlx)"
        )
    if family is None or not is_mlx:
        raise ValueError(
            "not an MLX model; look for an mlx-community build, or add it through Ollama"
        )
    size = sum(s.size or 0 for s in info.siblings or [])
    return family, size


def new_custom_model(request: NewModel) -> Model:
    source = request.source.strip()
    folder = Path(source).expanduser()
    if folder.is_absolute() or source.startswith("~"):
        if not folder.is_dir():
            raise ValueError(f"{folder} is not a folder")
        family = folder_family(folder)
        if family is None:
            raise ValueError("the folder needs an MLX model: config.json plus .safetensors weights")
        source, size = str(folder), folder_size(folder)
    elif "/" in source:
        try:
            family, size = inspect_hub_repo(source)
        except ValueError:
            raise
        except Exception as error:
            raise ValueError(f"could not read {source} from Hugging Face: {error}") from None
    else:
        raise ValueError(
            "enter a Hugging Face repo such as mlx-community/whisper-small-mlx, or a folder path"
        )
    title = request.title or Path(source).name
    return Model(
        custom_id(family, source), FAMILY_KIND[family], family, source, title, "custom", size
    )


def model_router(engine: "Engine", downloads: Downloads) -> APIRouter:
    router = APIRouter(prefix="/v1/models")

    @router.get("")
    def list_models() -> dict:
        jobs = downloads.status()
        return {
            "active": {"asr": engine.asr.name, "cleanup": engine.cleanup.name},
            "models": [
                {**m.to_dict(), "installed": is_installed(m), "download": jobs.get(m.id)}
                for m in all_models()
                if m.family != "ollama"
            ],
        }

    @router.post("/download", status_code=202)
    def download(ref: ModelRef) -> dict:
        model = find(ref.id)
        if model is None or model.family == "builtin" or model.is_local_folder:
            raise HTTPException(400, f"{ref.id} is not a downloadable model")
        return downloads.start(model).__dict__

    @router.post("/custom")
    def add_custom(request: NewModel) -> dict:
        try:
            model = new_custom_model(request)
        except ValueError as error:
            raise HTTPException(400, str(error)) from None
        existing = [m for m in load_custom() if m.id != model.id]
        save_custom([*existing, model])
        return {**model.to_dict(), "installed": is_installed(model)}

    @router.post("/remove")
    def remove(ref: ModelRef) -> dict:
        """Forgets a custom model and deletes downloaded files; local folders stay on disk."""
        model = find(ref.id)
        if model is None:
            raise HTTPException(404, f"unknown model {ref.id!r}")
        if ref.id in (engine.asr.name, engine.cleanup.name):
            raise HTTPException(409, "switch to another model before removing this one")
        if model.group == "recommended" and model.family == "builtin":
            raise HTTPException(400, f"{ref.id} has no files to remove")
        if not model.is_local_folder:
            remove_download(model.source)
        downloads.forget(model.id)
        if model.group == "custom":
            save_custom([m for m in load_custom() if m.id != model.id])
        return {"removed": model.id}

    return router
