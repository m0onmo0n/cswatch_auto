# CS Demo Processor
⚠️⚠️⚠️⚠️ This repo is currently untested on a new system and the launch_d2v.bat or the run_multi.bat/multi threaded processor dosen't work as it should(gives more error than necessary) ⚠️⚠️⚠️⚠️

Automates the workflow of downloading a Counter-Strike 2 demo, analyzing it, recording highlights of a specified player, and uploading the result to YouTube. It runs a local web UI so you can queue jobs and let it churn in the background.

This repo is the folder structure *I*, Moon Moon, uses. It also has both the pipelined version and the single(normal) version bundled with it aswell as the **CS Demo Manager (CSDM)** CLI fork made by Norton; which means you most likely don’t need the official CSDM GUI installed to use this project as this project defaults to using a remote DB hosted by our lovely Patty.
IF you wish to use your own DB, you can change the credentials in the config.ini file after the fact and create your own DB using postgres.
This repo also bundles obs portable.

pre-requisites to use this project are steam and cs2, everything else gets installed*.

note: my plan was to package obs portable with the rest of the project, but the size is too great for github; thus i cannot.
The dependency installer will install obs normally, most likely in the normal programfiles if it dosen't detect obs installed in the obs folder.

## Project layout
```
cswatch_auto/
├─ d2v_setup_wizard.bat      # main guided installer/repair UI (double-click)
├─ launch_d2v.bat            # quick launcher UI → run_single / run_multi
├─ obs_path.txt              # saved full path to obs64.exe (created by run_* once)
├─ setup_csdm.py             # one-time CSDM settings (.csdm[-dev]\settings.json + csdm-fork\.env)
├─ README.md                 # this file
│
├─ csdm-fork/                # CSDM fork (CLI/dev server)
│  ├─ package.json
│  ├─ .env                   # created by setup_csdm.py
│  └─ scripts/
│     └─ develop-cli.mjs
│
├─ d2v_multi/
│  ├─ main.py
│  ├─ setup.py               # interactive config → writes d2v_multi\config.ini
│  ├─ setup_youtube_auth.py
│  ├─ requirements.txt
│  └─ config.ini             # after setup (Paths/OBS/Video)
│
├─ d2v_single/
│  ├─ main.py
│  ├─ setup.py               # interactive config → writes d2v_single\config.ini
│  ├─ setup_youtube_auth.py
│  ├─ requirements.txt
│  └─ config.ini             # after setup
│
├─ demos/                    # default demos path
├─ obs/                      # portable OBS folder (obs\bin\64bit\obs64.exe)
├─ obs_videos/               # OBS recording output
└─ scripts/                  # helper scripts (called by the wizard/launchers)
   ├─ install_single.bat
   ├─ install_multi.bat
   ├─ run_single.bat
   ├─ run_multi.bat
   ├─ youtube_auth_single.bat
   ├─ youtube_auth_multi.bat
   ├─ launch_ytauth.bat      # optional standalone YouTube auth menu
   └─ install_dependencies.bat


```
> All BATs inside scripts\ include a repo-root resolver, so they work when called from anywhere.

---
## How to download:
you're gonna need to use either powershell or the app "terminal" located [here](https://github.com/microsoft/terminal)
To download, you need "git" installed(`winget install git.git`)
then you need to clone the repo (`git clone https://github.com/m0onmo0n/cswatch_auto.git cswatch_auto`) and you're done, make sure to do this command in the area you want the folder structure/repo to live; i.e wherever you do this command at is where the folder and repo will live(so please go into your documents or secondary harddrive to do it and not your system32 directory)
## First-time setup (Windows)

1. **Open the wizard**
    Double-click d2v_setup_wizard.bat.

2. Check prerequisites
    Wizard → [4] Check prerequisites (view Python/Node/NVM).
    If present, you can run install_dependencies.bat from there.

3. **Install D2V**
    In the wizard: [1] Install D2V → choose Single, Multi, or Both.
    This installs each flavor’s Python deps (pip -r requirements.txt).

4. **Configure**
    Wizard → [2] Config setup → choose Single, Multi, or Both.

    * Defaults point to sibling folders:
        ..\csdm-fork, ..\demos, ..\obs_videos.

    * Accept defaults or enter absolute paths.

5. **CSDM settings (one-time)**
    Wizard → [2] Config setup → [C] CSDM settings (or [3] Install/Repair CSDM).
    This writes:

    * %USERPROFILE%\.csdm-dev\settings.json

    * %USERPROFILE%\.csdm\settings.json

    * csdm-fork\.env

6. **YouTube auth**
    Wizard will prompt after installs/config, or run scripts\launch_ytauth.bat.

7. **Launch**
    Double click on launch_d2v.bat and choose your flavour :)

```


### Manual launch (advanced)
- **CSDM dev server**
  ```powershell
  cd csdm-fork
  node scripts/develop-cli.mjs
  ```
- **Processor + web server**
  ```powershell
  cd <d2v_single | d2v_multi> (depending on what flavour you want)
  python main.py
  ```
---


## Troubleshooting

**“Python/Node not recognized” after install**
- Close and reopen the terminal, or just use `run.bat` (it resolves both for the current window).
- Python: `py -3 --version` should work immediately (Python Launcher is installed).
- Node/NVM: `nvm use 20.19.1`. If NVM lives in unusual locations (e.g., `C:\nvm4w` with symlink `C:\nvm4w\nodejs`), `run.bat` detects those too.

**CSDM dev server errors about missing native modules**
- Force a rebuild of the native addon:
  ```powershell
  cd cs-demo-processor\csdm-fork\src\node\os\get-running-process-exit-code
  $env:GYP_MSVS_VERSION='2022'
  ..\..\..\node_modules\.bin\node-gyp.cmd rebuild --msvs_version=2022
  ```

**`npm ci` fails with libuv assertion or esbuild “spawn UNKNOWN”**
- Use Node **20.19.1**:
  ```powershell
  nvm use 20.19.1
  cmd /c rd /s /q node_modules
  npm cache clean --force
  npm ci
  npm rebuild esbuild --force
  ```
  Also ensure antivirus isn’t blocking `node_modules\esbuild\esbuild.exe`.

**Processor says `Configuration error: 'Paths'`**
- Run `python setup.py` again to regenerate `config.ini`. Fill all keys under `[Paths]` (output dir, ffmpeg, OBS settings).

**OBS WebSocket**
- OBS ≥ 28: built-in at Tools → WebSocket Server Settings (port **4455**).  
  No plugin needed. If using a password, put it in `config.ini`.

**Firewall prompts**
- On first run, allow Python (Flask) on `localhost:5001`.  
  OBS WebSocket on port 4455 should be allowed for local connections.

---

