from flask import Flask, render_template, request, jsonify
import queue
import logging
from collections import deque
import os
import json
from threading import Lock
import re

app = Flask(__name__)
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

# --- UPDATED: Three independent queues for each stage ---
prep_queue = queue.Queue()
record_queue = queue.Queue()
upload_queue = queue.Queue()

# Global dictionary to hold the status of each worker
status_prep = {"status": "Idle", "step": "Waiting for demos..."}
status_record = {"status": "Idle", "step": "Waiting for prepped demos..."}
status_upload = {"status": "Idle", "step": "Waiting for recorded videos..."}

RESULTS_FILE = 'results.json'
completed_jobs = deque(maxlen=50) 
results_lock = Lock()

def save_results():
    with results_lock:
        try:
            with open(RESULTS_FILE, 'w') as f:
                json.dump(list(completed_jobs), f, indent=4)
            logging.info(f"Successfully saved {len(completed_jobs)} results to {RESULTS_FILE}")
        except Exception as e:
            logging.error(f"Failed to save results to {RESULTS_FILE}: {e}")

def load_results():
    with results_lock:
        if os.path.exists(RESULTS_FILE):
            with open(RESULTS_FILE, 'r') as f:
                try:
                    content = f.read()
                    if content:
                        results_list = json.loads(content)
                        completed_jobs.extend(results_list)
                        logging.info(f"Loaded {len(completed_jobs)} previous results from {RESULTS_FILE}")
                except json.JSONDecodeError:
                    logging.error(f"Could not decode JSON from {RESULTS_FILE}. Starting with empty results.")
        else:
            logging.info(f"{RESULTS_FILE} not found. Starting with empty results.")

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/add_demo', methods=['POST'])
def add_demo():
    share_code = request.form.get('share_code')
    suspect_steam_id = request.form.get('suspect_steam_id')
    submitted_by = request.form.get('submitted_by')

    if not all([share_code, suspect_steam_id, submitted_by]):
        return jsonify({"success": False, "message": "All fields are required."}), 400

    # The initial job goes into the prep_queue
    job = {"share_code": share_code, "suspect_steam_id": suspect_steam_id, "submitted_by": submitted_by}
    prep_queue.put(job)
    logging.info(f"Added new job to Prep Queue: {job}")
    
    return jsonify({"success": True, "message": "Demo added to the queue."})

@app.route('/add_bulk', methods=['POST'])
def add_bulk():
    jobs_data = request.get_json()
    if not jobs_data or not isinstance(jobs_data, list):
        return jsonify({"success": False, "message": "Invalid data format."}), 400

    added_count = 0
    for job_item in jobs_data:
        share_code = job_item.get('share_code')
        suspect_steam_id = job_item.get('suspect_steam_id')
        submitted_by = job_item.get('submitted_by')

        if all([share_code, suspect_steam_id, submitted_by]):
            job = {"share_code": share_code, "suspect_steam_id": suspect_steam_id, "submitted_by": submitted_by}
            prep_queue.put(job)
            added_count += 1
        else:
            logging.warning(f"Skipping invalid bulk job item: {job_item}")
    
    logging.info(f"Added {added_count} new jobs to Prep Queue from bulk submission.")
    return jsonify({"success": True, "message": f"Successfully added {added_count} demos to the queue."})

UPLOAD_DIR = r"E:\cswatch_auto\obs_videos"  # Change this to your folder
    
def find_file_by_steam_id(steam_id):
    """
    Locate the .mp4 file corresponding to a specific Steam ID
    using the naming scheme: 'suspect {steam_id} *.mp4'.

    Returns full path if found, else None.
    """
    pattern = re.compile(rf"^suspect\s+{re.escape(steam_id)}\s+.*\.mp4$", re.IGNORECASE)
    candidates = []

    for filename in os.listdir(UPLOAD_DIR):
        if pattern.match(filename):
            full_path = os.path.join(UPLOAD_DIR, filename)
            candidates.append(full_path)

    if not candidates:
        return None

    # If multiple matches, pick the most recent one
    latest_file = max(candidates, key=os.path.getctime)
    return latest_file

@app.route('/status')
def status():
    return jsonify({
        "status_prep": status_prep,
        "status_record": status_record,
        "status_upload": status_upload,
        "queue_prep": list(prep_queue.queue),
        "queue_record": list(record_queue.queue),
        "queue_upload": list(upload_queue.queue),
        "results": list(completed_jobs) 
    })
    
@app.route('/retry', methods=['POST'])
def retry():
    data = request.get_json()
    steam_id = data.get('steam_id')

    if not steam_id:
        return jsonify({"success": False, "message": "Missing Steam ID"}), 400

    original_job = next((job for job in completed_jobs if job["suspect_steam_id"] == steam_id), None)

    if not original_job:
        return jsonify({"success": False, "message": "No completed job found for this Steam ID"}), 404

    # Use the original file path (rebuild from naming scheme if needed)
    # Locate the file associated with this Steam ID
    file_path = find_file_by_steam_id(steam_id)  # You implement this

    if not file_path:
        return jsonify({"success": False, "message": "File not found"}), 404

    retry_job = {
        "file_path": file_path,
        "suspect_steam_id": steam_id,
        "share_code": original_job.get("share_code", "N/A"),
        "submitted_by": original_job.get("submitted_by", "N/A")
    }
    upload_queue.put(retry_job)  # Add the file/job to the upload queue
    logging.info(f"Retry job queued for Steam ID {steam_id}: {file_path}")

    return jsonify({"success": True})

def run_web_server():
    load_results()
    app.run(host='0.0.0.0', port=5001)
