import sys
import os
import time

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import requests
from tqdm import tqdm
import config
import base64
import json
from typing import Optional
from openai import OpenAI
from pydantic import BaseModel
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
from collections import deque
from concurrent.futures import ThreadPoolExecutor, as_completed
from pprint import pprint
from tqdm import tqdm
from studios.dna import DnaStudio
from utils import utils
from studios.dance_inn import DanceInnStudio
from studios.vins import VinsStudio
from studios.manifest import ManifestStudio
from fastapi.responses import HTMLResponse
from fastapi import Depends
from utils import require_admin_session


class WorkshopTimeDetails(BaseModel):
    day: Optional[int]
    month: Optional[int]
    year: Optional[int]
    start_time: Optional[str]  # Example format: "07:00 PM"
    end_time: Optional[str]  # Example format: "09:00 PM"


class WorkshopDetails(BaseModel):
    time_details: WorkshopTimeDetails
    by: Optional[str]
    song: Optional[str]
    pricing_info: Optional[str]
    timestamp_epoch: Optional[
        int
    ]  # The Unix epoch timestamp for the workshop's start time
    artist_id: Optional[str]


class WorkshopSummary(BaseModel):
    is_workshop: bool
    workshop_details: list[WorkshopDetails]


import datetime


def process_link_debug(link, studio_id, client, artists, mongo_client, version=0):
    """
    Processes a single link: Calls GPT for analysis and prints the resulting
    workshop data (if any).
    """
    try:
        # Prepare system prompt content
        system_prompt_content = (
            "You are given a URL to analyze whether it contains information about a "
            "Bangalore-based dance workshop. Follow these steps:\n\n"
            "1. Access and parse the webpage at the provided URL.\n"
            "2. If the page does NOT describe a dance workshop in Bangalore, respond with:\n"
            "{\n"
            '"is_workshop": false,\n'
            '"workshop_details": []\n'
            "}\n\n"
            "3. If it DOES describe a Bangalore-based dance workshop, respond in the following "
            'JSON format with "is_workshop": true and an array of workshop details in '
            '"workshop_details". The array may have one or multiple objects, each with:\n\n'
            '   - "time_details":\n'
            '       * "day": integer day of the month\n'
            '       * "month": integer month (1–12)\n'
            '       * "year": 4-digit year\n'
            "         - If no year is specified but the event date is clearly in the future, "
            "assume the earliest valid future year.\n"
            '       * "start_time": string (12-hour format "HH:MM AM/PM")\n'
            '       * "end_time": string (12-hour format "HH:MM AM/PM")\n\n'
            '   - "by": string containing the instructor's name(s). If multiple instructors, '
            'use " x " to separate.\n'
            '   - "song": the routine name if specified; otherwise null.\n'
            '   - "pricing_info": a single string with the base price details. If more than '
            "one ticket type, split each price onto a new line. Exclude additional taxes or fees.\n"
            '   - "timestamp_epoch": integer representing the start date/time in Unix epoch.\n'
            '   - "artist_id": string matching the instructor's ID (if it matches any provided '
            "in the artists list), otherwise null.\n\n"
            "4. Important details:\n"
            "   - Parse textual event dates into numeric day, month, year.\n"
            "   - Use 12-hour clock format for times.\n"
            "   - If multiple routines or ticket types are listed, create multiple objects in "
            '"workshop_details". If they share the same date/time, use the same "time_details".\n'
            "   - Return valid JSON with no extra text:\n"
            "     {\n"
            '         "is_workshop": <boolean>,\n'
            '         "workshop_details": [\n'
            "             {\n"
            '                 "time_details": {\n'
            '                     "day": <int>,\n'
            '                     "month": <int>,\n'
            '                     "year": <int>,\n'
            '                     "start_time": <string>,\n'
            '                     "end_time": <string>\n'
            "                 },\n"
            '                 "by": <string or null>,\n'
            '                 "song": <string or null>,\n'
            '                 "pricing_info": <string or null>,\n'
            '                 "timestamp_epoch": <int or null>,\n'
            '                 "artist_id": <string or null>\n'
            "             }\n"
            "         ]\n"
            "     }\n\n"
            "5. Do not include extra explanations or text; return only the JSON.\n"
            '6. Use the provided artists data to find any matching "artist_id". If no match, use null.\n'
            "7. Convert textual date references to numeric day, month, year. If the year is missing, assume future.\n"
            "8. Use 12-hour clock format for times.\n"
            '9. Make "timestamp_epoch" the start date/time in Unix epoch.\n'
            "10. Return only that JSON.\n\n"
            f"Artists Data for additional context: {artists}\n\n"
            f"Current Date for reference: {datetime.date.today().strftime('%B %d, %Y')}\n"
        )

        # Prepare user prompt referencing the URL
        user_prompt_content = (
            "Please analyze the webpage at the following URL to determine if it describes "
            "a Bangalore-based dance workshop according to the system instructions. "
            "Output only the required JSON.\n\n"
            f"URL: {link}"
        )

        # Send prompts to GPT
        response = client.beta.chat.completions.parse(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": system_prompt_content},
                {"role": "user", "content": user_prompt_content},
            ],
            response_format=WorkshopSummary,
        )

        # Parse the JSON given by GPT
        analyzed_data = json.loads(response.choices[0].message.content)

    except Exception as e:
        print(f"Error processing AI response for link {link}: {e}")
        return

    print(system_prompt_content, user_prompt_content)

    # If the AI indicates it is not a Bangalore-based workshop, skip.
    if not analyzed_data["is_workshop"]:
        return

    payment_link = link
    # Construct a unique ID for debugging or storage
    uuid = (
        f"{studio_id}/{link.split('/')[-1]}"
        if studio_id != "dance_n_addiction"
        else f"{studio_id}/{link.split('/')[-3]}"
    )

    # Print out the final dictionary for debugging
    pprint(
        {
            "payment_link": payment_link,
            "studio_id": studio_id,
            "uuid": uuid,
            "workshop_details": analyzed_data["workshop_details"],
            "updated_at": utils.get_current_timestamp(),
            "version": version,
        }
    )

import secrets
import hashlib
import base64

def hash_password(plain_password):
    salt = secrets.token_bytes(16)
    hash_bytes = hashlib.pbkdf2_hmac('sha256', plain_password.encode(), salt, 100_000)
    return f"{base64.b64encode(salt).decode()}${base64.b64encode(hash_bytes).decode()}"




# Example usage:
if __name__ == "__main__":

    print(hash_password("Vishal2002"))
    pass
    # client = utils.get_mongo_client()
    # openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    # process_link_debug(
    #     link="https://rzp.io/rzp/mar-junaid",
    #     studio_id="vins.dance.co",
    #     client=openai_client,
    #     artists=list(client["discovery"]["artists_v2"].find({}, {"artist_id": 1, "artist_name": 1})),
    #     mongo_client=client,
    #     version=1
    # )
    # url = "https://danceinn.studio/workshops/upcoming-workshops/"

    time_1 = utils.get_timestamp_epoch(
        {"day": 2, "month": 5, "year": 2025, "start_time": "12:00 PM", "end_time": None}
    )
    time_2 = utils.get_timestamp_epoch(
        {
            "day": 25,
            "month": 5,
            "year": 2025,
            "start_time": "07:00 PM",
            "end_time": "09:00 PM",
        }
    )
    print(time_1, time_2)
    print(time_1 < time_2)

    pass

@app.get("/admin", response_class=HTMLResponse)
async def admin_panel(user=Depends(require_admin_session)):
    return f"""
    <html>
    <head>
      <title>Admin Panel</title>
      <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; }}
        .logout {{ position: absolute; top: 20px; right: 20px; }}
        h2 {{ color: #007bff; }}
      </style>
    </head>
    <body>
      <a class="logout" href="/admin/logout">Logout</a>
      <h2>Welcome to the Admin Panel</h2>
      <p>You are logged in as: <b>{user['username']}</b></p>
      <hr>
      <h3>Sections (to be implemented):</h3>
      <ul>
        <li>List of Studios</li>
        <li>List of Artists</li>
        <li>List of Workshops</li>
        <li>CRUD operations for all</li>
      </ul>
      <p>Start building your admin UI here!</p>
    </body>
    </html>
    """
