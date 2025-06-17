import jwt
import datetime
import time
import requests
import json
import os

# --- Configuration ---
# Replace with your actual App Store Connect API credentials
ISSUER_ID = "0ef0c565-d5c1-485a-ba48-0a9922d3443e"  # e.g., "XXXX-XX-XXXXXX-XX-XXXXXXXX"
KEY_ID = "Q4RV625Q5U"  # e.g., "XXXXXXXX"
AUTH_KEY_FILE = "AuthKey_Q4RV625Q5U.p8"  # Make sure this file is in the same directory or provide full path


# --- 1. Generate App Store Connect API Token ---
def generate_token(issuer_id, key_id, auth_key_file):
    try:
        with open(auth_key_file, 'r') as f:
            private_key = f.read()

        # Token expiration time (20 minutes from now)
        expiration_time = int(time.time()) + (20 * 60)

        payload = {
            "iss": issuer_id,
            "exp": expiration_time,
            "aud": "appstoreconnect-v1"
        }

        headers = {
            "kid": key_id
        }

        token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
        return token
    except FileNotFoundError:
        print(f"Error: API key file '{auth_key_file}' not found.")
        exit(1)
    except Exception as e:
        print(f"Error generating token: {e}")
        exit(1)


# --- 2. API Helper Functions ---
def make_api_request(method, url, token, data=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    try:
        if method == "GET":
            response = requests.get(url, headers=headers)
        elif method == "DELETE":
            response = requests.delete(url, headers=headers)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data)
        elif method == "PATCH":
            response = requests.patch(url, headers=headers, json=data)
        else:
            raise ValueError(f"Unsupported HTTP method: {method}")

        response.raise_for_status()  # Raise an exception for HTTP errors (4xx or 5xx)
        return response.json() if response.content else {}  # Handle empty response content
    except requests.exceptions.HTTPError as e:
        print(f"HTTP error occurred: {e.response.status_code} - {e.response.text}")
        return None
    except requests.exceptions.ConnectionError as e:
        print(f"Connection error occurred: {e}")
        return None
    except requests.exceptions.Timeout as e:
        print(f"Timeout error occurred: {e}")
        return None
    except requests.exceptions.RequestException as e:
        print(f"An error occurred during the request: {e}")
        return None


# --- Main Script ---
if __name__ == "__main__":
    print("Generating App Store Connect API token...")
    app_store_token = generate_token(ISSUER_ID, KEY_ID, AUTH_KEY_FILE)
    if not app_store_token:
        exit(1)
    print("Token generated successfully.")

    # You can uncomment and use this if you want to export the token to an environment variable
    # os.environ['APPSTORETOKEN'] = app_store_token

    # --- [OPTIONAL STEP] Get additional information about your app store app ---
    # Replace <APP_STORE_ID_NUMBER> with your actual App Store ID
    APP_STORE_ID = input("Enter your App Store ID (e.g., 123456789): ")
    if not APP_STORE_ID:
        print("App Store ID cannot be empty. Exiting.")
        exit(1)

    print("\n--- Optional: Fetching App Information ---")

    # List Apps (Example)
    # apps_url = "https://api.appstoreconnect.apple.com/v1/apps"
    # apps_data = make_api_request("GET", apps_url, app_store_token)
    # if apps_data:
    #     print("Apps:")
    #     for app in apps_data.get('data', []):
    #         print(f"  ID: {app['id']}, Name: {app['attributes']['name']}")

    # Get App Store Versions
    app_versions_url = f"https://api.appstoreconnect.apple.com/v1/apps/{APP_STORE_ID}/relationships/appStoreVersions"
    app_versions_data = make_api_request("GET", app_versions_url, app_store_token)
    if app_versions_data and 'data' in app_versions_data:
        print(f"\nApp Store Versions for App ID {APP_STORE_ID}:")
        for version in app_versions_data['data']:
            print(f"  Version ID: {version['id']}, Type: {version['type']}")
            # You might need to fetch the actual version number via appStoreVersions/<id> endpoint
    else:
        print(f"Could not retrieve App Store Versions for App ID {APP_STORE_ID}.")

    # --- Find appStoreVersionLocalization ID ---
    # This step often requires manual inspection from the browser console as you described.
    # For automation, you'd typically list all localizations and find the one you need.

    # Example of how you'd list all localizations for a specific appStoreVersion ID
    # You'll need to replace 'YOUR_APP_STORE_VERSION_ID' with the actual ID you want to target.
    # You can get this ID from the 'app_versions_data' printed above or by making another API call.

    print("\n--- Finding App Store Version Localization ---")
    app_store_version_id_to_target = input(
        "Enter the App Store Version ID you want to target (e.g., from the list above): ")
    if not app_store_version_id_to_target:
        print("App Store Version ID cannot be empty. Exiting.")
        exit(1)

    app_localizations_url = f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{app_store_version_id_to_target}/appStoreVersionLocalizations"
    app_localizations_data = make_api_request("GET", app_localizations_url, app_store_token)

    target_app_store_version_localization_id = None
    if app_localizations_data and 'data' in app_localizations_data:
        print(f"\nApp Store Version Localizations for Version ID {app_store_version_id_to_target}:")
        for localization in app_localizations_data['data']:
            localization_id = localization['id']
            locale = localization['attributes']['locale']
            print(f"  Localization ID: {localization_id}, Locale: {locale}")
            # You might want to pick a specific locale, e.g., 'en-US'
            # if locale == 'en-US':
            #     target_app_store_version_localization_id = localization_id
            #     break

        if not target_app_store_version_localization_id:
            target_app_store_version_localization_id = input(
                "Enter the specific App Store Version Localization ID to delete screenshots for (e.g., 21XXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX): ")
            if not target_app_store_version_localization_id:
                print("App Store Version Localization ID cannot be empty. Exiting.")
                exit(1)
    else:
        print(f"Could not retrieve App Store Version Localizations for Version ID {app_store_version_id_to_target}.")
        exit(1)

    # --- List all appScreenshotSets and get their IDs ---
    print(f"\n--- Listing App Screenshot Sets for Localization ID {target_app_store_version_localization_id} ---")
    screenshot_sets_url = f"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{target_app_store_version_localization_id}/appScreenshotSets"
    screenshot_sets_data = make_api_request("GET", screenshot_sets_url, app_store_token)

    app_screenshot_set_ids_to_delete = []
    if screenshot_sets_data and 'data' in screenshot_sets_data:
        print("Found App Screenshot Sets:")
        for screenshot_set in screenshot_sets_data['data']:
            set_id = screenshot_set['id']
            app_screenshot_set_ids_to_delete.append(set_id)
            print(f"  App Screenshot Set ID: {set_id}")
    else:
        print("No App Screenshot Sets found for this localization or an error occurred.")

    # --- DELETE EVERY LAST ONE OF THEM ---
    if app_screenshot_set_ids_to_delete:
        print("\n--- Deleting App Screenshot Sets ---")
        confirmation = input(
            f"Are you sure you want to delete {len(app_screenshot_set_ids_to_delete)} App Screenshot Set(s)? Type 'yes' to confirm: ")
        if confirmation.lower() == 'yes':
            for set_id in app_screenshot_set_ids_to_delete:
                delete_url = f"https://api.appstoreconnect.apple.com/v1/appScreenshotSets/{set_id}"
                print(f"  Attempting to delete App Screenshot Set: {set_id}...")
                delete_result = make_api_request("DELETE", delete_url, app_store_token)
                if delete_result is not None:  # A successful delete often returns an empty response, so check for not None
                    print(f"    Successfully deleted {set_id}.")
                else:
                    print(f"    Failed to delete {set_id}.")
            print("\nDeletion process complete.")
        else:
            print("Deletion cancelled by user.")
    else:
        print("No App Screenshot Sets to delete.")