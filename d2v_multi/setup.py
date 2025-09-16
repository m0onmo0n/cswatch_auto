# setup.py — shared for d2v_single/ and d2v_multi/
import os
import configparser
from pathlib import Path

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def _norm_path(p: str) -> Path:
    return Path(os.path.expandvars(p)).expanduser().resolve()

def ask_str(prompt: str, default: str | None = None) -> str:
    text = f"{prompt} [default: {default}]\n> " if default else f"{prompt}\n> "
    val = input(text).strip()
    return val if val else (default or "")

def ask_bool(prompt: str, default: bool = False) -> bool:
    dtxt = "yes" if default else "no"
    val = input(f"{prompt} [default: {dtxt}]\n> ").strip().lower()
    if val == "": return default
    if val in ("y","yes","t","true","1"): return True
    if val in ("n","no","f","false","0"): return False
    print("  Unrecognized input; using default.")
    return default

def ask_path(prompt: str, default: Path, must_exist: bool, create_if_missing: bool) -> str:
    while True:
        raw = input(f"{prompt} [default: {default}]\n> ").strip()
        chosen = _norm_path(raw) if raw else default
        if must_exist:
            if chosen.exists():
                return str(chosen)
            print("  ERROR: That path doesn't exist. Please try again.")
            continue
        if not chosen.exists() and create_if_missing:
            try:
                chosen.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                print(f"  ERROR: Could not create directory: {e}")
                continue
        return str(chosen)

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
DEFAULT_CSDM  = (REPO_ROOT / "csdm-fork").resolve()
DEFAULT_DEMOS = (REPO_ROOT / "demos").resolve()
DEFAULT_OUT   = (REPO_ROOT / "obs_videos").resolve()

DEFAULT_OBS_HOST = "localhost"
DEFAULT_OBS_PORT = "4455"
DEFAULT_VIDEO_GENERATE_ONLY = False

def main():
    clear_screen()
    print("=================================================================")
    print("== Demo2Video Setup (per flavor)                               ==")
    print("=================================================================")
    print(f"Detected repo root: {REPO_ROOT}")
    print("Press Enter to accept defaults shown in brackets.\n")

    csdm_project_path = ask_path(
        "Full path to your CSDM project folder (csdm-fork)",
        default=DEFAULT_CSDM,
        must_exist=True,
        create_if_missing=False
    )
    demos_folder = ask_path(
        "Folder where downloaded demo files (.dem) will be stored",
        default=DEFAULT_DEMOS,
        must_exist=False,
        create_if_missing=True
    )
    output_folder = ask_path(
        "Folder where OBS saves recorded videos (.mp4)\n"
        "IMPORTANT: Must match OBS Settings -> Output -> Recording -> Recording Path",
        default=DEFAULT_OUT,
        must_exist=False,
        create_if_missing=True
    )

    obs_host = ask_str("OBS WebSocket host", default=DEFAULT_OBS_HOST)
    obs_port = ask_str("OBS WebSocket port", default=DEFAULT_OBS_PORT)
    video_generate_only = ask_bool(
        "Enable 'Video Generate Only' by default? (Save locally; don't upload to YouTube)",
        default=DEFAULT_VIDEO_GENERATE_ONLY
    )

    cfg = configparser.ConfigParser()
    cfg["Paths"] = {
        "csdm_project_path": csdm_project_path,
        "demos_folder":      demos_folder,
        "output_folder":     output_folder,
    }
    cfg["OBS"] = {"host": obs_host, "port": obs_port}
    cfg["Video"] = {"video_generate_only": "true" if video_generate_only else "false"}

    out_path = HERE / "config.ini"
    with open(out_path, "w", encoding="utf-8") as f:
        cfg.write(f)

    print("\n--- Success! ---")
    print(f"config.ini written to: {out_path}\n")
    print("[Paths]")
    print(f"csdm_project_path = {csdm_project_path}")
    print(f"demos_folder      = {demos_folder}")
    print(f"output_folder     = {output_folder}")
    print("\n[OBS]")
    print(f"host = {obs_host}")
    print(f"port = {obs_port}")
    print("\n[Video]")
    print(f"video_generate_only = {'true' if video_generate_only else 'false'}")

    # Multi-only: update settings.txt if helper exists
    if HERE.name.lower() == "d2v_multi":
        helper = HERE / "setup_settings_txt.py"
        if helper.exists():
            try:
                import importlib.util
                spec = importlib.util.spec_from_file_location("setup_settings_txt", helper)
                mod = importlib.util.module_from_spec(spec)
                assert spec and spec.loader
                spec.loader.exec_module(mod)
                mod.main()
            except Exception as e:
                print(f"\n[WARN] settings.txt step skipped: {e}")
        else:
            print("\n[INFO] setup_settings_txt.py not found; skipping settings.txt.")

    input("\nDone. Press Enter to exit.")

if __name__ == "__main__":
    main()
