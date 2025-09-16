import os
import configparser
import json

def clear_screen():
    """Clears the terminal screen."""
    os.system('cls' if os.name == 'nt' else 'clear')

def get_valid_path(prompt, must_exist=True):
    """Prompts the user for a path and validates it."""
    while True:
        path = input(prompt).strip()
        if must_exist and not os.path.exists(path):
            print("\nERROR: The path you entered does not exist. Please try again.\n")
            continue
        if not must_exist:
            parent_dir = os.path.dirname(path)
            if parent_dir and not os.path.exists(parent_dir):
                os.makedirs(parent_dir, exist_ok=True)
        return path

def main():
    """Runs the interactive setup process for the application."""
    clear_screen()
    print("=================================================================")
    print("== Welcome to the CS Demo Processor Interactive Setup          ==")
    print("=================================================================")
    print("\nThis script will help you create the 'config.ini' file required to run the application.")
    print("Please have the following information ready:")
    print("  - The full path to the folder where OBS saves its recordings.")
    print("\nPress Enter to begin...")
    input()
    clear_screen()

    # --- Get Main App Settings ---
    print("--- Step 1: Main Application Configuration ---\n")
    output_folder = get_valid_path("Enter the full path to your OBS output folder (e.g., Z:\\Videos\\OBS):\n> ")
    
    clear_screen()

    # --- Get OBS Settings ---
    print("--- Step 2: OBS Settings ---\n")
    print("These settings must match what you have configured in OBS under 'Tools -> obs-websocket Settings'.")
    obs_host = input("Enter the OBS WebSocket host (usually 'localhost'):\n> ") or 'localhost'
    obs_port = input("Enter the OBS WebSocket port (usually '4455'):\n> ") or '4455'

    # --- Create Main App config.ini ---
    main_app_config = configparser.ConfigParser()
    main_app_config['Paths'] = {
        'output_folder': output_folder
    }
    main_app_config['OBS'] = {
        'host': obs_host,
        'port': obs_port
    }

    try:
        with open('config.ini', 'w') as configfile:
            main_app_config.write(configfile)
        print("\n--- Success! ---\n")
        print("'config.ini' has been created successfully.")
    except Exception as e:
        print(f"\nERROR: An error occurred while writing the config file: {e}")
        input("\nPress Enter to exit.")
        return

    print("\n=================================================================")
    print("== Configuration complete. What's next?                      ==")
    print("=================================================================")
    print("\n1. YouTube Setup: Run 'python setup_youtube_auth.py' to authorize the app.")
    print("\n2. Start OBS: Open OBS Studio and leave it running.")
    print("\n3. Run the App: Double-click 'run.bat' to start the server and open the UI.")
    
    input("\nPress Enter to exit the setup.")

if __name__ == "__main__":
    main()
