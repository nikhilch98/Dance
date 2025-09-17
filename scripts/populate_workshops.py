"""Workshop data population script for the Dance Workshop application.

This module handles fetching and updating workshop information from various
dance studios and storing it in the database. It includes functionality for
workshop details extraction and validation.
"""

import base64
from enum import Enum
import sys
import os
import time
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, date
from typing import List, Optional, Dict, Any
import json
import pymongo
import pytz
from openai import OpenAI
from pydantic import BaseModel
from tqdm import tqdm
import logging

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config
from utils.utils import DatabaseManager, ScreenshotManager, retry, generate_uuid
from studios.dna import DnaStudio
from studios.dance_inn import DanceInnStudio
from studios.vins import VinsStudio
from studios.manifest import ManifestStudio


class EventType(Enum):
    WORKSHOP = "workshop"
    INTENSIVE = "intensive"
    REGULARS = "regulars"

# Data Models
class TimeDetails(BaseModel):
    """Event time details."""

    day: Optional[int] = None
    month: Optional[int] = None
    year: Optional[int] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None


class EventDetails(BaseModel):
    """Event session details."""

    time_details: List[TimeDetails] # Multiple time details can be present for a multi day event , for example in case of intensive or regulars which might span for multiple days
    by: Optional[str] = None
    song: Optional[str] = None
    pricing_info: Optional[str] = None
    artist_id_list: Optional[List[str]] = []


class EventSummary(BaseModel):
    """Event summary including all details."""

    event_type: EventType
    event_details: List[EventDetails]
    is_valid: bool


class EventProcessor:
    """Event data processing and management system."""

    def __init__(self, client: OpenAI, artists: List[Dict], mongo_client: Any, cfg: config.Config):
        """Initialize event processor."""
        self.client = client
        self.artists = artists
        self.mongo_client = mongo_client
        self.cfg = cfg

    def process_link(
        self, link: str, studio: Any, version: int = 0, artists_data: list = []
    ) -> Optional[Dict]:
        """Process a single workshop link and return workshop data."""
        screenshot_path = (
            f"screenshots/{studio.config.studio_id}_{link.split('/')[-1]}.png"
        )

        try:
            # Capture screenshot
            if not ScreenshotManager.capture_screenshot(link, screenshot_path):
                return None

            # Analyze screenshot with selected AI model
            response = self.analyze_with_ai(screenshot_path, artists_data)
            # Check response validity using the correct attribute
            if not response or not response.is_valid:
                return None

            # Prepare event data for bulk update
            if studio.config.studio_id in ["dance_n_addiction", "manifestbytmn"]:
                # Handle potential index errors if URL structure is unexpected
                uuid = f"{studio.config.studio_id}/{link.split('/')[-3]}"
            else:
                uuid = f"{studio.config.studio_id}/{link.split('/')[-1]}"

            # Rename to event_data and include event_type
            event_data = {
                "payment_link": link,
                "studio_id": studio.config.studio_id,
                "uuid": uuid,
                "event_type": response.event_type.value, # Add event_type
                "event_details": [
                    detail.model_dump() for detail in response.event_details # Use event_details
                ],
                "updated_at": time.time(),
                "version": version,
            }

            return event_data # Return event_data

        except Exception as e:
            print(f"Error processing link {link}: {str(e)}")
            return None
        finally:
            #Cleanup screenshot
            if os.path.exists(screenshot_path):
                try:
                    os.remove(screenshot_path)
                except Exception as e:
                    print(f"Error cleaning up screenshot {screenshot_path}: {str(e)}")
            pass

    def analyze_with_ai(self, screenshot_path: str, artists_data: list = []) -> Optional[EventSummary]:
        """Analyze workshop screenshot using the selected AI model."""
        if self.cfg.ai_model == "openai":
            return self._analyze_with_ai(screenshot_path, artists_data=artists_data, model_version="gpt-4o-2024-11-20")
        elif self.cfg.ai_model == "gemini":
            return self._analyze_with_ai(screenshot_path, artists_data=artists_data, model_version="gemini-2.5-flash")
        else:
            raise ValueError(f"Unknown ai_model: {self.ai_model}")

    def _generate_prompt(self, artists, current_date):
        """Generates the prompt for the AI model."""
        try:
            return (
                "You are given data about an event (potentially a dance workshop, intensive, or regulars class). "
                "You must analyze the provided text and image (the screenshot) to determine "
                "the type of event and extract its details if it's a Bangalore-based dance event.\n\n"
                f"Artists Data for additional context : {artists}\n\n"
                f"Current Date for reference : {current_date}\n\n"
                "1. Determine if the event is a dance workshop, intensive, or regulars class based in Bangalore.\n"
                "2. If it is NOT a valid Bangalore-based dance event OR if the event is in the past based on the current date, set `is_valid` to `false`, "
                "   `event_type` to null, and provide an empty list for `event_details`.\n"
                "3. If it IS a valid Bangalore-based dance event, set `is_valid` to `true`, determine the `event_type` ('workshop', 'intensive', or 'regulars'), and "
                "   return a list of one or more event objects under `event_details` with the "
                "   following structure:\n\n"
                "   **`event_details`:** (array of objects)\n"
                "   Each object must have:\n"
                "   - **`time_details`:** (array of objects) Each time object contains details for one session/day:\n"
                "     * **`day`**: integer day of the month (null if not found)\n"
                "     * **`month`**: integer month (1–12) (null if not found)\n"
                "     * **`year`**: 4-digit year (null if not found).\n"
                "       - If no year is specified but the event date is clearly in the future relative to the current date, "
                "         choose the earliest valid future year. Otherwise, use the current year if the month/day suggest it's upcoming, or null.\n"
                '     * **`start_time`**: string, 12-hour format "HH:MM AM/PM" with leading zeros (e.g., "01:00 PM", "05:30 AM"). Null if not found.\n'
                '     * **`end_time`**: string, 12-hour format "HH:MM AM/PM" with leading zeros (e.g., "01:00 PM", "05:30 AM"). Null if not found.\n'
                '     * NOTE: Only intensives or regulars typically have multiple entries in `time_details` array (for multiple days/sessions). Workshops usually have only one.\n\n'
                "   - **`by`**: string with the instructor's name(s). If multiple, use ' X ' to separate. Null if not found.\n"
                "   - **`song`**: string with the routine/song name if available, else null.\n"
                "   - **`pricing_info`**: string if pricing is found, else null. Format multiple tiers/options separated by a newline character '\\n'. Do not include taxes/fees like GST , Service charge , etc. \n"
                "   - **`artist_id_list`**: array of strings. If the instructor(s) in `by` match entries in the provided artists list, use those `artist_id`s; otherwise empty array. For multiple instructors, include all matching artist_ids.\n\n"
                "   **IMPORTANT Extraction Notes**:\n"
                "   - If multiple distinct classes/routines are offered within the same event post (e.g., different songs/styles with separate pricing/times), create a separate object in `event_details` for each.\n"
                "   - If different routines share the same date/time, use the same `time_details` object(s) for each corresponding `event_details` object.\n"
                "   - Prioritize information from sections explicitly labeled 'Workshop Details', 'Event Details', 'Session Details', 'About Event', etc., especially for timings, song, and pricing.\n"
                "   - For 'Dance N Addiction' studio posts specifically, look for an 'About event details' or 'session details' section for potentially more accurate information.\n\n"
                "4. Only return a valid JSON object with this exact structure:\n"
                "   ```json\n"
                "   {\n"
                '       "is_valid": <boolean>,\n'
                '       "event_type": <"workshop" | "intensive" | "regulars" | null>,\n'
                '       "event_details": [\n'
                "           {\n"
                '               "time_details": [\n'
                "                   {\n"
                '                       "day": <int | null>,\n'
                '                       "month": <int | null>,\n'
                '                       "year": <int | null>,\n'
                '                       "start_time": <string | null>,\n'
                '                       "end_time": <string | null>\n'
                "                   }\n"
                "                   // ... more time objects if applicable (intensive/regulars)\n"
                "               ],\n"
                '               "by": <string | null>,\n'
                '               "song": <string | null>,\n'
                '               "pricing_info": <string | null>,\n'
                '               "artist_id_list": <array of strings>\n'
                "           }\n"
                "           // ... more event objects if applicable (multiple distinct routines)\n"
                "       ]\n"
                "   }\n"
                "   ```\n\n"
                "5. Do not include any extra text, explanations, or formatting outside the JSON structure.\n"
                "6. Ensure all string values in the JSON are properly escaped.\n"
                "7. Use the provided `artists` data *only* for matching and populating `artist_id_list`. Do not infer other details from it.\n"
                "8. Return only the raw JSON object."
            )
        except Exception as e:
            logging.error(f"Error generating prompt: {e}")
            # Optionally return a default safe prompt or raise the exception
            # For now, returning a basic error message or re-raising
            raise  # Or return a default prompt string

    def _analyze_with_ai(
        self, screenshot_path: str, artists_data: list, model_version:str
    ) -> Optional[EventSummary]:
        """Analyze workshop screenshot using GPT.

        Args:
            screenshot_path: Path to the screenshot file
            artists_data: List of artist data for context

        Returns:
            EventSummary object or None
        """
        try:
            # Read screenshot file
            with open(screenshot_path, "rb") as image_file:
                base64_image = base64.b64encode(image_file.read()).decode("utf-8")

            # Prepare GPT request
            response = self.client.beta.chat.completions.parse(
                model=model_version,
                messages=[
                    {
                        "role": "system",
                        "content": self._generate_prompt(artists_data, date.today().strftime("%B %d, %Y")),
                    },
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "Description of the workshop"},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/png;base64,{base64_image}",
                                    "detail": "high",
                                },
                            },
                        ],
                    },
                ],
                response_format=EventSummary,
            )

            # Parse GPT response
            analyzed_data = json.loads(response.choices[0].message.content)
            if "gpt" in model_version:
                time.sleep(2)
            # Convert to EventSummary using correct keys and models
            event_details_list = []
            for detail_data in analyzed_data.get("event_details", []):
                time_details_list = [
                    TimeDetails(**td) for td in detail_data.get("time_details", [])
                ]
                event_details_list.append(
                    EventDetails(
                        time_details=time_details_list,
                        by=detail_data.get("by"),
                        song=detail_data.get("song"),
                        pricing_info=detail_data.get("pricing_info"),
                        artist_id_list=detail_data.get("artist_id_list", []),
                    )
                )

            return EventSummary(
                is_valid=analyzed_data.get("is_valid", False), # Use is_valid
                event_type=analyzed_data.get("event_type"), # Use event_type
                event_details=event_details_list # Use event_details
            )

        except Exception as e:
            print(f"GPT analysis error: {str(e)}")
            return None


class StudioProcessor:
    """Studio data processing system."""

    def __init__(
        self,
        client: OpenAI,
        artists: List[Dict],
        mongo_client: Any,
        version: int,
        position: int,
        cfg: config.Config
    ):
        """Initialize studio processor."""
        self.event_processor = EventProcessor(client, artists, mongo_client, cfg)
        self.version = version
        self.position = position
        self.mongo_client = mongo_client

    def process_studio(self, studio: Any, artists_data: list) -> None:
        """Process all workshops for a studio with bulk update."""
        try:
            links = set(x.lower() for x in studio.scrape_links())
            workshop_updates = []
            ignored_links = set()
            missing_artists = set()
            old_links = set()
            with tqdm(
                total=len(links),
                desc=f"Processing {studio.config.studio_id}",
                position=self.position,
                leave=False,
            ) as pbar:
                for link in links:
                    # Rename variable to event_data
                    event_data = self.event_processor.process_link(
                        link, studio, self.version, artists_data
                    )

                    if event_data:
                        # Iterate through event_details using event_detail
                        for event_detail in event_data["event_details"]:
                            inserted_data = {
                                "payment_link": link, # Can be url payment link or whatsapp number as string
                                "payment_link_type" : "url", # Can be url or whatsapp
                                "studio_id": studio.config.studio_id,
                                "uuid": event_data["uuid"], # Use event_data
                                "event_type": event_data["event_type"], # Add event_type
                                "time_details": event_detail["time_details"], # Use event_detail
                                "by": event_detail["by"].lower() if event_detail["by"] else None, # Use event_detail
                                "song": event_detail["song"].lower() if event_detail["song"] else None, # Use event_detail
                                "pricing_info": event_detail["pricing_info"], # Use event_detail
                                "artist_id_list": sorted(event_detail["artist_id_list"]), # Use event_detail
                                "updated_at": time.time(),
                                "version": self.version,
                                "choreo_insta_link": None,
                                "is_archived": False,
                            }
                            if event_detail["song"] and event_detail["artist_id_list"]:
                                choreo_link = self.mongo_client["discovery"]["choreo_links"].find_one({"song": event_detail["song"].lower(), "artist_id_list": event_detail["artist_id_list"]})
                                if choreo_link:
                                    inserted_data["choreo_insta_link"] = choreo_link["choreo_insta_link"]

                            # Check if the event is in the past using the first time_details entry
                            is_past_event = False
                            first_time_detail = next(iter(event_detail.get("time_details", [])), None)

                            if event_data["event_type"] == "workshop" and first_time_detail :
                                event_year = int(first_time_detail.get("year") or 0)
                                event_month = int(first_time_detail.get("month") or 0)
                                event_day = int(first_time_detail.get("day") or 0)
                                now_ist = datetime.now(pytz.timezone('Asia/Kolkata'))

                                if event_year < now_ist.year or \
                                    (event_year == now_ist.year and event_month < now_ist.month) or \
                                    (event_year == now_ist.year and event_month == now_ist.month and event_day < now_ist.day):
                                    is_past_event = True

                            if is_past_event:
                                old_links.add(link)
                                ignored_links.add(link)
                            else:
                                workshop_updates.append(inserted_data)
                                # Check artist_id from event_detail
                                if not event_detail["artist_id_list"]:
                                    # Add tuple of (link, original 'by' field) for context
                                    missing_artists.add((link, event_detail.get("by"))) # Store link and 'by'
                    else:
                        ignored_links.add(link)

                    pbar.update(1)

            # Perform bulk update for the entire studio
            if workshop_updates:
                # Remove existing workshops for this studio before inserting new ones
                delete_result = self.mongo_client["discovery"][
                    "workshops_v2"
                ].delete_many({"studio_id": studio.config.studio_id})

                # Insert new workshops for this studio
                insert_result = self.mongo_client["discovery"][
                    "workshops_v2"
                ].insert_many(workshop_updates)

                print(
                    f"\nDeleted {delete_result.deleted_count} existing workshops for {studio.config.studio_id}"
                )
                print(
                    f"Inserted {len(insert_result.inserted_ids)} new workshops for {studio.config.studio_id}"
                )
            return ignored_links, old_links, missing_artists, studio.config.studio_id
        except Exception as e:
            print(f"Error processing studio {studio.config.studio_id}: {str(e)}")
            return [], [], [], studio.config.studio_id


def get_artists_data(cfg: config.Config) -> List[Dict]:
    """Get artist data from database."""
    client = DatabaseManager.get_mongo_client(
        "prod" if cfg.mongodb_uri == config.PROD_MONGODB_URI else "dev"
    )
    return list(
        client["discovery"]["artists_v2"].find({}, {"artist_id": 1, "artist_name": 1})
    )


def parse_arguments():
    parser = argparse.ArgumentParser(description="Populate workshops data.")

    parser.add_argument(
        "--env",
        required=True,
        choices=["prod", "dev"],
        help="Set the environment (prod or dev)",
    )

    parser.add_argument(
        "--studio",
        required=True,
        choices=[
            "all",
            "dna",
            "danceinn",
            "vins",
            "manifest",
        ],
        help="Specify the studio to populate workshops for",
    )

    parser.add_argument(
        "--ai_model",
        required=True,
        choices=["openai", "gemini"],
        help="Choose which AI model to use: openai or gemini",
    )

    return parser.parse_args()


def main():
    """Main execution function."""
    # Parse command-line arguments
    args = parse_arguments()

    # Determine environment
    env = args.env

    # Parse environment configuration
    cfg = config.Config(env=args.env, ai_model=args.ai_model)

    # Initialize clients
    artists = get_artists_data(cfg)
    if cfg.ai_model == "openai":
        client = OpenAI(api_key=cfg.openai_api_key)
    elif cfg.ai_model == "gemini":
        client = OpenAI(api_key=cfg.gemini_api_key, base_url=cfg.gemini_base_url)
    else:
        raise ValueError(f"Invalid ai_model: {args.ai_model}")
    mongo_client = DatabaseManager.get_mongo_client(env)

    # Verify database connection
    if not mongo_client["admin"].command("ping"):
        print("MongoDB is not running")
        return

    version = 1
    all_studios = [
        DnaStudio(
            "https://www.yoactiv.com/eventplugin.aspx?Apikey=ZL0C5CwgOJzo38yELwSW%2Fg%3D%3D",
            "dance_n_addiction",
            "https://www.yoactiv.com/Event/",
            max_depth=1,
        ),
        DanceInnStudio(
            "https://danceinn.studio/workshops/upcoming-workshops/",
            "dance.inn.bangalore",
            "https://rzp.io/rzp/",
        ),
        VinsStudio(
            "https://www.vinsdanceco.com/workshops",
            "vins.dance.co",
            "https://www.vinsdanceco.com/events/",
            max_depth=1,
        ),
        ManifestStudio(
            "https://www.yoactiv.com/eventplugin.aspx?Apikey=xwbn1XX+5R9oZfATr4CsLw%3D%3D",
            "manifestbytmn",
            "https://www.yoactiv.com/Event/",
            max_depth=1,
        ),
    ]

    # Filter studios based on command-line argument
    studio_arg_map = {
        "dna": "dance_n_addiction",
        "danceinn": "dance.inn.bangalore",
        "vins": "vins.dance.co",
        "manifest": "manifestbytmn",
        "all": "all",
    }
    studios = (
        all_studios
        if args.studio == "all"
        else [
            studio for studio in all_studios if studio.config.studio_id == studio_arg_map[args.studio]
        ]
    )

    artists_data = list(
        mongo_client["discovery"]["artists_v2"].find(
            {}, {"artist_id": 1, "artist_name": 1}
        )
    )

    # Process studios in parallel
    with ThreadPoolExecutor(max_workers=len(studios)) as executor:
        futures = []
        for position, studio in enumerate(studios):
            processor = StudioProcessor(
                client=client,
                artists=artists,
                mongo_client=mongo_client,
                version=version,
                position=position,
                cfg=cfg
            )
            futures.append(
                executor.submit(processor.process_studio, studio, artists_data)
            )
        ignored_links_set = set()
        # Wait for completion and handle errors
        for future in as_completed(futures):
            try:
                ignored_links, old_links, missing_artists, studio_id = future.result()
                for link in ignored_links:
                    ignored_links_set.add(link)
                if ignored_links:
                    print(f"Ignored Links for {studio_id} : {ignored_links}")
                if missing_artists:
                    print(f"Missing artists links for {studio_id} : {missing_artists}")
                if old_links:
                    print(f"Old links for {studio_id} : {old_links}")
            except Exception as e:
                print(f"Error in studio processing thread: {str(e)}")

    # Optional: Clean up old data
    # mongo_client["discovery"]["workshops_v2"].delete_many(
    #     {
    #         "$or": [
    #             {"version": {"$nin": [version]}},
    #             {"version": {"$exists": False}},
    #         ]
    #     }
    # )


if __name__ == "__main__":
    main()
