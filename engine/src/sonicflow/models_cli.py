import argparse
import sys
import time

from sonicflow.downloads import Downloads, remove_download
from sonicflow.models import all_models, find, is_installed


def _gb(size: int | None) -> str:
    return f"{size / 1e9:.2f} GB" if size else "-"


def main() -> None:
    parser = argparse.ArgumentParser(prog="sonicflow-models", description="List and fetch models")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list", help="every model, its group, and whether it is installed")
    for name in ("download", "remove"):
        command = commands.add_parser(name)
        command.add_argument("ids", nargs="+")
    args = parser.parse_args()

    if args.command == "list":
        for model in all_models():
            mark = "*" if is_installed(model) else " "
            print(
                f"{mark} {model.kind:<7} {model.group:<11} {model.id:<28} {_gb(model.size_bytes)}"
            )
        return

    for model_id in args.ids:
        model = find(model_id)
        if model is None or model.family == "builtin" or model.is_local_folder:
            sys.exit(f"{model_id} is not a downloadable model")
        if args.command == "remove":
            print(f"{model_id}: {'removed' if remove_download(model.source) else 'not downloaded'}")
            continue
        if is_installed(model):
            print(f"{model_id}: already downloaded")
            continue
        downloads = Downloads()
        downloads.start(model)
        while (job := downloads.status()[model_id])["state"] in ("queued", "downloading"):
            total = job["total_bytes"] or 0
            print(
                f"\r{model_id}: {job['bytes'] / 1e6:,.0f} / {total / 1e6:,.0f} MB",
                end="",
                flush=True,
            )
            time.sleep(1)
        print()
        if job["state"] == "error":
            sys.exit(f"{model_id}: download failed: {job['error']}")
