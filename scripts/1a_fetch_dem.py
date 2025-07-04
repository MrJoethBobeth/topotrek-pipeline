import os
import sys
import time
import requests

# This script fetches a Digital Elevation Model (DEM) from the OpenTopography API.
# It includes a retry mechanism to handle transient server-side errors (like HTTP 500).

# --- Configuration ---
API_KEY = sys.argv[1]
BBOX = [float(coord) for coord in sys.argv[2].split(',')] # min_lon, min_lat, max_lon, max_lat
OUTPUT_PATH = sys.argv[3]
MAX_RETRIES = 3 # Number of times to retry on failure

API_URL = "https://portal.opentopography.org/API/globaldem"

params = {
    "demtype": "SRTMGL3",
    "south": BBOX[1],
    "north": BBOX[3],
    "west": BBOX[0],
    "east": BBOX[2],
    "outputFormat": "GTiff",
    "API_Key": API_KEY,
}

print("Downloading DEM for bounding box:", BBOX)

for attempt in range(MAX_RETRIES):
    try:
        response = requests.get(API_URL, params=params, stream=True)

        # If the request was successful, process the file
        if response.status_code == 200:
            content_type = response.headers.get('content-type', '')
            # MODIFIED LINE: Accept 'application/octet-stream' as a valid content type
            if 'image/tiff' in content_type or 'application/octet-stream' in content_type:
                with open(OUTPUT_PATH, "wb") as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
                print(f"SUCCESS: DEM saved to {OUTPUT_PATH}")
                sys.exit(0) # Exit successfully
            else:
                print(f"ERROR: API returned content of type '{content_type}', which is not a GeoTIFF image.", file=sys.stderr)
                print("The first 100 bytes of the response are:", response.content[:100], file=sys.stderr)
                sys.exit(1)
        
        # If we get a server error, wait and retry
        elif response.status_code >= 500:
            print(f"Server error (HTTP {response.status_code}) on attempt {attempt + 1}/{MAX_RETRIES}. Retrying in 5 seconds...", file=sys.stderr)
            time.sleep(5)
            continue # Go to the next attempt

        # For other client-side errors, fail immediately
        else:
            print(f"ERROR: API request failed with status code {response.status_code}.", file=sys.stderr)
            print("Response text:", response.text, file=sys.stderr)
            sys.exit(1)

    except requests.exceptions.RequestException as e:
        print(f"ERROR: A network error occurred on attempt {attempt + 1}/{MAX_RETRIES}: {e}", file=sys.stderr)
        time.sleep(5)

# If all retries fail
print("ERROR: All attempts to download the DEM failed.", file=sys.stderr)
sys.exit(1)