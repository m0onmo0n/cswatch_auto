# d2v_multi/setup_settings_txt.py
import os
import shutil
from pathlib import Path

TEMPLATE = """# settings file

# Path where recorded videos are stored before upload. should match the video path in config.ini [Paths]->output_folder.
# e.g E:\\cswatch_auto\\obs_videos
UPLOAD_DIR= {upload_dir}

# Logging directory. Leave blank to use "logs" in the project folder.
LOG_DIR= {log_dir}

# Path to your csdm-fork directory.
# Leave blank to use the one bundled with the project.
CSDM_PROJECT_PATH= {csdm_path}

# Path where demo files will be downloaded.
# default: E:\\cswatch_auto\\demos
# Leave blank to default inside the csdm-fork/demos folder.
DEMOS_FOLDER= {demos_dir}
"""

def _norm(p: Path | str) -> str:
    return str(Path(p).expanduser().resolve())

def _prompt_path(label: str, default: Path, create: bool) -> str:
    print(f"{label}\n  [Enter for default]\n  Default: {default}")
    raw = input("> ").strip()
    p = Path(raw).expanduser().resolve() if raw else default
    if not p.exists() and create:
        p.mkdir(parents=True, exist_ok=True)
        print(f"  -> Created: {p}")
    return _norm(p)

def main():
    here = Path(__file__).resolve().parent          # ...\d2v_multi
    repo = here.parent                               # ...\cswatch_auto

    default_upload = repo / "obs_videos"
    default_demos  = repo / "demos"
    default_csdm   = repo / "csdm-fork"

    print("=== Demo2Video (multi) — settings.txt setup ===\n")
    csdm_path  = _prompt_path("Path to csdm-fork directory:", default_csdm, create=False)
    demos_dir  = _prompt_path("Folder for downloaded demos (.dem):", default_demos, create=True)
    upload_dir = _prompt_path("OBS recording/output folder (.mp4):", default_upload, create=True)
    log_dir = ""  # keep blank → app uses local d2v_multi\logs by default

    dst = here / "settings.txt"
    if dst.exists():
        try:
            shutil.copy2(dst, dst.with_suffix(".txt.bak"))
            print(f"\nBacked up settings.txt -> {dst.with_suffix('.txt.bak')}")
        except Exception as e:
            print(f"\n[WARN] Could not backup settings.txt: {e}")

    content = TEMPLATE.format(
        upload_dir=_norm(upload_dir),
        log_dir=log_dir,
        csdm_path=_norm(csdm_path),
        demos_dir=_norm(demos_dir),
    )
    dst.write_text(content, encoding="utf-8")
    print(f"\nWrote: {dst}")

if __name__ == "__main__":
    main()
