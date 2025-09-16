import sys
import os
import configparser
import logging
import time
import threading
import datetime
import requests

import csdm_cli_handler
import youtube_uploader
import demo_downloader
from obs_recorder import OBSRecorder
from web_server import (
    prep_queue, record_queue, upload_queue,
    status_prep, status_record, status_upload,
    completed_jobs, run_web_server, save_results
)



SETTINGS_FILE = "settings.txt"

def read_setting(key, default):
    """Read key=value from settings.txt, fallback to default if missing."""
    try:
        with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    if k.strip().lower() == key.lower():
                        return v.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return default

def wait_for_file_ready(filepath, timeout=120, check_interval=2):
    """
    Wait until a file is stable (not being written to).
    """
    logging.info(f"Waiting for OBS to finish writing {filepath}...")
    start_time = time.time()
    last_size = -1

    while time.time() - start_time < timeout:
        try:
            current_size = os.path.getsize(filepath)
            if current_size == last_size:  # size hasn't changed
                logging.info(f"File {filepath} is ready.")
                return True
            last_size = current_size
        except FileNotFoundError:
            pass  # OBS might not have created it yet
        time.sleep(check_interval)

    raise TimeoutError(f"File {filepath} was not ready after {timeout} seconds.")



def setup_logging():
    log_dir = 'logs'
    os.makedirs(log_dir, exist_ok=True)
    log_filename = f"csdm_processor_{time.strftime('%Y-%m-%d_%H-%M-%S')}.log"
    log_filepath = os.path.join(log_dir, log_filename)
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(threadName)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_filepath, encoding='utf-8'),
            logging.StreamHandler(sys.stdout)
        ]
    )

def prep_worker(config):
    """Worker for Stage 1: Download and Analyze Demos."""
    logging.info("Prep worker started.")

    config = configparser.ConfigParser()
    config.read('config.ini')
    try:
        default_csdm = config['Paths']['csdm_project_path']
        csdm_project_path = os.path.normpath(read_setting("CSDM_PROJECT_PATH", default_csdm))

        default_demos = config['Paths']['demos_folder']
        demos_folder = os.path.normpath(read_setting("DEMOS_FOLDER", default_demos))

        os.makedirs(demos_folder, exist_ok=True)
        if not os.path.isdir(csdm_project_path):
            raise FileNotFoundError("The 'csdm-fork' directory was not found.")
    except (KeyError, FileNotFoundError) as e:
        logging.error(f"Prep worker configuration error: {e}")
        return

    while True:
        job = prep_queue.get()
        suspect_id = job['suspect_steam_id']
        status_prep.update({"status": "Processing", "step": f"Downloading for {suspect_id}"})
        
        try:
            share_code = demo_downloader.parse_share_code(job['share_code'])
            if not share_code:
                raise ValueError("Invalid share code.")
            
            demo_path = demo_downloader.download_demo(share_code, demos_folder)
            if not demo_path:
                raise RuntimeError("Failed to download demo.")
            
            status_prep.update({"status": "Processing", "step": f"Analyzing for {suspect_id}"})
            if not csdm_cli_handler.analyze_demo(csdm_project_path, demo_path):
                raise RuntimeError("Demo analysis failed.")
            
            record_job = {**job, "demo_path": demo_path}
            record_queue.put(record_job)
            logging.info(f"Prep successful for {suspect_id}. Added to record queue.")

        except Exception as e:
            logging.error(f"Prep stage failed for {suspect_id}: {e}")
        
        finally:
            time.sleep(5)
            status_prep.update({"status": "Idle", "step": "Waiting for demos..."})
            prep_queue.task_done()

def record_worker(config):
    """Worker for Stage 2: Record Highlights."""
    logging.info("Record worker started.")
    try:
        csdm_project_path = os.path.join(os.getcwd(), 'csdm-fork')
        if not os.path.isdir(csdm_project_path):
            raise FileNotFoundError("The 'csdm-fork' directory was not found.")
        obs_host = config['OBS']['host']
        obs_port = int(config['OBS']['port'])
    except (KeyError, FileNotFoundError) as e:
        logging.error(f"Record worker configuration error: {e}")
        return
        
    obs = OBSRecorder(host=obs_host, port=obs_port)

    while True:
        job = record_queue.get()
        suspect_id = job['suspect_steam_id']
        status_record.update({"status": "Processing", "step": f"Recording for {suspect_id}"})
        
        try:
            obs.connect()
            if not obs.is_connected:
                raise RuntimeError("Could not connect to OBS.")
            
            highlights_process = csdm_cli_handler.start_highlights(csdm_project_path, job['demo_path'], suspect_id)
            if not highlights_process:
                raise RuntimeError("Failed to launch highlights.")

            # UPDATED: Reordered the logic to start recording AFTER the game has loaded.
            if not csdm_cli_handler.wait_for_cs2_to_start(highlights_process):
                raise RuntimeError("CS2 did not launch or the highlights script failed early.")
            
            status_record.update({"status": "Recording", "step": f"Starting OBS recording for {suspect_id}"})
            obs.start_recording()

            status_record.update({"status": "Recording", "step": f"Waiting for highlights to finish for {suspect_id}"})
            if not csdm_cli_handler.wait_for_cs2_to_close():
                raise RuntimeError("Timed out waiting for CS2 process to close.")

            obs.stop_recording()
            # UPDATED: Increased delay to 15 seconds to ensure file is saved.
            logging.info("Waiting 25 seconds for OBS to save the video file...")
            time.sleep(25)

            # Attach the path to the recorded video so retries know what to upload
            upload_job = {**job}
            upload_queue.put(upload_job)

            logging.info(f"Recording successful for {suspect_id}. Added to upload queue.")

        except Exception as e:
            logging.error(f"Record stage failed for {suspect_id}: {e}")
            if obs.is_recording:
                obs.stop_recording()
        
        finally:
            if obs.is_connected:
                obs.disconnect()
            csdm_cli_handler.force_close_cs2()
            status_record.update({"status": "Idle", "step": "Waiting for prepped demos..."})
            record_queue.task_done()

def upload_worker(config):
    """Worker for Stage 3: Upload to YouTube."""
    logging.info("Upload worker started.")
    try:
        output_folder = config['Paths']['output_folder']
    except KeyError as e:
        logging.error(f"Upload worker configuration error: {e}")
        return

    while True:
        job = upload_queue.get()
        suspect_id = job['suspect_steam_id']
        file_path = job.get('file_path')  # <-- Retry jobs will set this
        status_upload.update({"status": "Processing", "step": f"Uploading for {suspect_id}"})

        youtube_link = None
        try:
            if file_path and os.path.exists(file_path):
                latest_file = file_path
                logging.info(f"Using retry file: {latest_file}")
            else:
                files = [os.path.join(output_folder, f) for f in os.listdir(output_folder) if f.endswith('.mp4')]
                if not files:
                    raise FileNotFoundError("No .mp4 files found.")
                
                latest_file = max(files, key=os.path.getctime)
                logging.info(f"Latest recording found: {latest_file}")

            # 🔹 Wait until OBS is done writing
            wait_for_file_ready(latest_file)
            time.sleep(120)  # keep long enough buffer

            if not file_path:          
                timestamp = time.strftime('%d-%m_%H-%M')
                base_name = f"suspect {suspect_id} {timestamp}"
                final_video_path = os.path.join(output_folder, f"{base_name}.mp4")
                
                counter = 1
                while os.path.exists(final_video_path):
                    final_video_path = os.path.join(output_folder, f"{base_name}_{counter}.mp4")
                    counter += 1

                # 🔹 Rename only after file is ready
                os.rename(latest_file, final_video_path)
                logging.info(f"Renamed video file: {final_video_path}")
            else:
                final_video_path = latest_file
            
            video_title = f"Suspected Cheater: {suspect_id} - Highlights"
            youtube_link = youtube_uploader.upload_video(final_video_path, video_title)

            if youtube_link:
                logging.info("Upload complete!")
            else:
                logging.error("Upload did not return a URL.")

        except Exception as e:
            logging.error(f"Upload stage failed for {suspect_id}: {e}")
            youtube_link = "Upload Failed"

        finally:
            ts = time.time()
            timestamp_str = datetime.datetime.fromtimestamp(ts).strftime('%d/%m-%Y %H:%M:%S')

            # 🔹 Look for an existing completed job for this suspect_id
            existing = next((j for j in completed_jobs if j["suspect_steam_id"] == suspect_id), None)

            if existing:
                # Update in-place (retry case)
                logging.info(f"Updating existing completed job for Steam ID {suspect_id}")
                existing.update({
                    "timestamp": timestamp_str,
                    "youtube_link": youtube_link or "Upload Failed",
                })
            else:
                # First time completion (normal case)
                logging.info(f"Adding new completed job for Steam ID {suspect_id}")
                completed_jobs.append({
                    "timestamp": timestamp_str,
                    "suspect_steam_id": suspect_id,
                    "share_code": job.get('share_code', 'N/A'),
                    "youtube_link": youtube_link or "Upload Failed",
                    "submitted_by": job.get('submitted_by', 'N/A')
                })

            save_results()
            status_upload.update({"status": "Idle", "step": "Waiting for recorded videos..."})
            upload_queue.task_done()



if __name__ == '__main__':
    setup_logging()
    
    config = configparser.ConfigParser()
    config.read('config.ini')

    # --- Start all worker threads ---
    threading.Thread(target=prep_worker, args=(config,), daemon=True, name="PrepWorker").start()
    threading.Thread(target=record_worker, args=(config,), daemon=True, name="RecordWorker").start()
    threading.Thread(target=upload_worker, args=(config,), daemon=True, name="UploadWorker").start()

    logging.info("Starting web server on http://localhost:5001")
    run_web_server()
