import os
import json
from pathlib import Path
from getpass import getpass
from datetime import datetime

HERE = Path(__file__).resolve().parent            # cswatch_auto/
CSDM_FORK_DIR = HERE / "csdm-fork"                # cswatch_auto/csdm-fork
DEV_SETTINGS  = Path.home() / ".csdm-dev" / "settings.json"
PROD_SETTINGS = Path.home() / ".csdm" / "settings.json"
ENV_PATH      = CSDM_FORK_DIR / ".env"

DEFAULT_HOST = "csdm.xify.pro"
DEFAULT_PORT = 8432
DEFAULT_USER = "csdm"
DEFAULT_DB   = "csdm"

DEFAULT_WIDTH  = 1280
DEFAULT_HEIGHT = 720
DEFAULT_CLOSE_AFTER = True

def ts():
    return datetime.now().strftime("%Y%m%d-%H%M%S")

def ask(prompt, default=None):
    if default is not None:
        s = input(f"{prompt} [default: {default}]\n> ").strip()
        return s if s else str(default)
    return input(f"{prompt}\n> ").strip()

def ask_int(prompt, default):
    s = ask(prompt, default)
    try:
        return int(s)
    except ValueError:
        print("  Not a number, using default.")
        return int(default)

def yes_no(prompt, default=False):
    dtxt = "yes" if default else "no"
    s = input(f"{prompt} [default: {dtxt}]\n> ").strip().lower()
    if s == "": return default
    return s in ("y","yes","t","true","1")

def write_json_safe(path: Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_suffix(path.suffix + f".{ts()}.bak")
        try:
            backup.parent.mkdir(parents=True, exist_ok=True)
            path.replace(backup)
            print(f"[BACKUP] {path} -> {backup}")
        except Exception as e:
            print(f"[WARN] Could not backup {path}: {e}")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"[OK] Wrote {path}")

def write_text_safe(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_suffix(path.suffix + f".{ts()}.bak")
        try:
            path.replace(backup)
            print(f"[BACKUP] {path} -> {backup}")
        except Exception as e:
            print(f"[WARN] Could not backup {path}: {e}")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"[OK] Wrote {path}")

def main():
    print("==============================================================")
    print(" CSDM one-time setup — writes settings.json and csdm-fork/.env")
    print("==============================================================\n")

    host = ask("Database host", DEFAULT_HOST)
    port = ask_int("Database port", DEFAULT_PORT)
    user = ask("Database user", DEFAULT_USER)
    database = ask("Database name", DEFAULT_DB)

    pw = getpass("Database password (input hidden): ")
    while pw == "":
        print("  Password cannot be empty.")
        pw = getpass("Database password (input hidden): ")

    print("\nPlayback preferences (press Enter for defaults)")
    width  = ask_int("Playback width", DEFAULT_WIDTH)
    height = ask_int("Playback height", DEFAULT_HEIGHT)
    close_after = yes_no("Close game after highlights?", DEFAULT_CLOSE_AFTER)

    config = {
        "database": {
            "host": host,
            "port": port,
            "user": user,
            "password": pw,
            "database": database,
        },
        "playback": {
            "width": width,
            "height": height,
            "closeGameAfterHighlights": close_after,
        },
    }

    # Write dev/prod settings.json
    write_json_safe(DEV_SETTINGS, config)
    write_json_safe(PROD_SETTINGS, config)

    # Write csdm-fork/.env (if csdm-fork exists)
    if CSDM_FORK_DIR.exists():
        vite_url = f"VITE_DATABASE_URL=postgresql://{user}:{pw}@{host}:{port}/{database}"
        write_text_safe(ENV_PATH, vite_url)
    else:
        print(f"[WARN] {CSDM_FORK_DIR} not found; skipping .env. Clone csdm-fork first.")

    print("\nDone. You can re-run this script anytime to update credentials.")

if __name__ == "__main__":
    main()
