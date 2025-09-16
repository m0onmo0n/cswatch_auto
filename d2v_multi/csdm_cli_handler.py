import subprocess
import logging
import os
import time
import psutil

# This module handles all interactions with the CS Demo Manager CLI tools.

def analyze_demo(csdm_project_path, demo_path):
    """
    Runs the 'analyze' command on a demo file using the node CLI.
    """
    command = ['node', 'out/cli.js', 'analyze', demo_path]
    logging.info(f"Executing analysis command in '{csdm_project_path}': {' '.join(command)}")
    try:
        result = subprocess.run(
            " ".join(command), # Pass as a single string when shell=True
            cwd=csdm_project_path,
            capture_output=True,
            text=True,
            check=True,
            shell=True
        )
        logging.info("Analysis command completed successfully.")
        return True
    except subprocess.CalledProcessError as e:
        logging.error(f"Analysis command failed. Stderr: {e.stderr}")
        return False
    except Exception as e:
        logging.error(f"An unexpected error occurred during analysis: {e}")
        return False

def start_highlights(csdm_project_path, demo_path, steam_id_64):
    """
    Launches CS2 to play highlights for a specific player.
    """
    command = ['node', 'out/cli.js', 'highlights', f'"{demo_path}"', steam_id_64]
    logging.info(f"Executing highlights command in '{csdm_project_path}': {' '.join(command)}")
    
    try:
        process = subprocess.Popen(
            " ".join(command), # Pass as a single string when shell=True
            cwd=csdm_project_path,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            shell=True
        )
        logging.info(f"Highlights command sent. CS2 should be launching. Process PID: {process.pid}")
        return process
    except Exception as e:
        logging.error(f"An unexpected error occurred while starting highlights: {e}")
        return None

def wait_for_cs2_to_start(highlights_process, timeout=60):
    """
    Waits for the cs2.exe process to appear, while monitoring the launch script for errors.
    """
    logging.info("Waiting for cs2.exe process to appear...")
    start_time = time.time()
    while time.time() - start_time < timeout:
        if "cs2.exe" in (p.name() for p in psutil.process_iter()):
            logging.info("cs2.exe process found.")
            return True
        # Check if the node script failed and exited early
        if highlights_process.poll() is not None:
            stdout, stderr = highlights_process.communicate()
            logging.error(f"The CSDM highlights script exited prematurely. Stderr: {stderr.strip()}")
            return False
        time.sleep(1)

    logging.error(f"cs2.exe process did not appear within {timeout} seconds.")
    return False

def wait_for_cs2_to_close(timeout=1800):
    """
    Waits for the cs2.exe process to close.
    """
    logging.info("Now waiting for cs2.exe process to close...")
    start_time = time.time()
    while time.time() - start_time < timeout:
        if "cs2.exe" not in (p.name() for p in psutil.process_iter()):
            logging.info("cs2.exe process has closed. Highlights finished.")
            return True
        # Removed the repetitive "still running" log message
        time.sleep(2)

    logging.error(f"Timed out after {timeout} seconds waiting for cs2.exe to close.")
    return False

def force_close_cs2():
    """
    Forcefully terminates the Counter-Strike 2 process.
    """
    logging.info("Attempting to force-close Counter-Strike 2 (cs2.exe)...")
    try:
        # Use taskkill, which is the command-line equivalent of "End Task".
        # The /F flag makes it forceful, which is necessary for crashed processes.
        result = subprocess.run(['taskkill', '/F', '/IM', 'cs2.exe', '/T'],
                                capture_output=True, text=True, check=False)
        if result.returncode == 0:
            logging.info("CS2 terminated successfully.")
        elif result.returncode == 128:
            logging.warning("CS2 process not found (was likely already closed).")
        else:
            logging.error(f"Taskkill failed: {result.stderr.strip()}")
        time.sleep(2) # Give the OS a moment to clean up the process.
    except Exception as e:
        logging.error(f"Error closing CS2: {e}")
