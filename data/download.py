#!/usr/bin/env python3
"""Download the EpiQL input datasets from Google Drive.

Everything lands next to this script (see `data/README.md`); only the script,
the README and the dataset descriptors (`*.json`) are tracked by git.
"""

import argparse
import shutil
import sys
import zipfile
from pathlib import Path

FOLDERS = {
    "common": "https://drive.google.com/drive/folders/1UbXjq88h2wXYGltFCW4zmUppiPczb11N",
    "bel-10k": "https://drive.google.com/drive/folders/14fOi8EguSKi6AVwtRd3AcxyCs1mszd8y",
    "bel-100k": "https://drive.google.com/drive/folders/1O-VqdPecaUzIvx4XVUFS6s6WtTNkOoWg",
}

# Zip archives that hold a temporal input relation, i.e. a directory of
# `{timestep}.csv` / `{timestep}.parquet` files. Maps archive -> relation dir.
ARCHIVES = {
    "common/Calendar.zip": "common/Calendar",
}


def is_populated(path: Path) -> bool:
    return path.is_dir() and any(path.iterdir())


def download(name: str, dest: Path, force: bool) -> None:
    import gdown

    target = dest / name
    if is_populated(target) and not force:
        print(f"[skip] {name}: already present in {target} (use --force to re-download)")
        return

    print(f"[get ] {name} <- {FOLDERS[name]}")
    gdown.download_folder(
        url=FOLDERS[name],
        output=str(target),
        quiet=False,
        use_cookies=False,
        remaining_ok=True,
    )

    if not is_populated(target):
        sys.exit(
            f"error: nothing was downloaded into {target}.\n"
            "Google Drive may be rate-limiting the shared link, or the link expired.\n"
            f"You can fetch the folder manually from {FOLDERS[name]} "
            "(see data/README.md for the expected layout)."
        )


def extract_archives(dest: Path, force: bool) -> None:
    """Unpack zipped temporal relations into the directory layout the interpreter expects."""
    for archive, relation in ARCHIVES.items():
        zip_path = dest / archive
        out_dir = dest / relation
        if not zip_path.is_file():
            continue
        if is_populated(out_dir) and not force:
            print(f"[skip] {relation}: already extracted (use --force to re-extract)")
            continue
        if force and out_dir.is_dir():
            shutil.rmtree(out_dir)

        print(f"[unzip] {archive} -> {relation}/")
        with zipfile.ZipFile(zip_path) as zf:
            names = [n for n in zf.namelist() if not n.startswith("__MACOSX/")]
            top = out_dir.name + "/"
            # The archive either already contains a `Calendar/` top-level directory,
            # or the timestep files sit at its root.
            if names and all(n.startswith(top) for n in names):
                zf.extractall(out_dir.parent, members=names)
            else:
                zf.extractall(out_dir, members=names)


def main() -> None:
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dest", type=Path, default=here, help=f"where to put the data (default: {here})")
    parser.add_argument(
        "--dataset",
        action="append",
        choices=["all", *FOLDERS],
        help="dataset to download; repeatable (default: all)",
    )
    parser.add_argument("--force", action="store_true", help="re-download and re-extract even if already present")
    args = parser.parse_args()

    try:
        import gdown  # noqa: F401
    except ImportError:
        sys.exit("error: gdown is not installed. Install it with:\n    pip install gdown")

    selected = args.dataset or ["all"]
    names = list(FOLDERS) if "all" in selected else list(dict.fromkeys(selected))

    dest = args.dest.resolve()
    dest.mkdir(parents=True, exist_ok=True)

    for name in names:
        download(name, dest, args.force)
    extract_archives(dest, args.force)

    print(f"\nDone. Data is in {dest}")
    print('Point config.json at it with:  "input_datasets": "data/bel-10k.json"')


if __name__ == "__main__":
    main()
