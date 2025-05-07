"""Workshop data population script for the Dance Workshop application.

This module handles fetching and updating workshop information from various
dance studios and storing it in the database. It includes functionality for
workshop details extraction and validation.
"""

import base64
import sys
import os
import time
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, date
from typing import List, Optional, Dict, Any
import json
import pymongo

from openai import OpenAI
from pydantic import BaseModel
from tqdm import tqdm

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config
from utils.utils import DatabaseManager, ScreenshotManager, retry
from studios.dna import DnaStudio
from studios.dance_inn import DanceInnStudio
from studios.vins import VinsStudio
from studios.manifest import ManifestStudio


# Data Models
class TimeDetails(BaseModel):
    """Workshop time details."""

    day: Optional[int] = None
    month: Optional[int] = None
    year: Optional[int] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None


class WorkshopDetails(BaseModel):
    """Workshop session details."""

    time_details: TimeDetails
    by: Optional[str] = None
    song: Optional[str] = None
    pricing_info: Optional[str] = None
    timestamp_epoch: Optional[int] = None
    artist_id: Optional[str] = None


class WorkshopSummary(BaseModel):
    """Workshop summary including all details."""

    is_workshop: bool
    workshop_details: List[WorkshopDetails]


class WorkshopProcessor:
    """Workshop data processing and management system."""

    def __init__(self, client: OpenAI, artists: List[Dict], mongo_client: Any):
        """Initialize workshop processor."""
        self.client = client
        self.artists = artists
        self.mongo_client = mongo_client

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

            # Analyze screenshot with GPT
            response = self._analyze_with_gpt(
                screenshot_path, artists_data=artists_data
            )
            if not response or not response.is_workshop:
                print(link, "is not a workshop", response)
                return None

            # Prepare workshop data for bulk update
            if studio.config.studio_id in ["dance_n_addiction", "manifestbytmn"]:
                uuid = f"{studio.config.studio_id}/{link.split('/')[-3]}"
            else:
                uuid = f"{studio.config.studio_id}/{link.split('/')[-1]}"

            workshop_data = {
                "payment_link": link,
                "studio_id": studio.config.studio_id,
                "uuid": uuid,
                "workshop_details": [
                    detail.model_dump() for detail in response.workshop_details
                ],
                "updated_at": time.time(),
                "version": version,
            }

            return workshop_data

        except Exception as e:
            print(f"Error processing link {link}: {str(e)}")
            return None
        finally:
            # Cleanup screenshot
            if os.path.exists(screenshot_path):
                try:
                    os.remove(screenshot_path)
                except Exception as e:
                    print(f"Error cleaning up screenshot {screenshot_path}: {str(e)}")

    def _get_gpt_system_content(self, artists_data: list = []) -> str:
        """Generate system content for GPT prompt.

        Args:
            artists_data: List of artist data to include in context

        Returns:
            Formatted system prompt for GPT
        """
        artists = ", ".join(
            [
                f"{artist.get('artist_name')} (ID: {artist.get('artist_id')})"
                for artist in artists_data
            ]
        )
        current_date = date.today().strftime("%B %d, %Y")

        return (
            "You are given data about an event (potentially a dance workshop). "
            "You must analyze the provided text and image (the screenshot) to determine "
            "whether the event is a Bangalore-based dance workshop.\n\n"
            f"Artists Data for additional context : {artists}\n\n"
            f"Current Date for reference : {current_date}\n\n"
            "1. If it is NOT a dance workshop in Bangalore, or it is a regular weekly or monthly classes,  set `is_workshop` to `false` "
            "   and provide an empty list for `workshop_details`.\n"
            "2. If it IS a Bangalore-based dance workshop, set `is_workshop` to `true` and "
            "   return a list of one or more workshop objects under `workshop_details` with the "
            "   following structure:\n\n"
            "   **`workshop_details`:** (array of objects)\n"
            "   Each object must have:\n"
            "   - **`time_details`:** (object) with:\n"
            "     * **`day`**: integer day of the month\n"
            "     * **`month`**: integer month (1–12)\n"
            "     * **`year`**: 4-digit year.\n"
            "       - If no year is specified but the event date is clearly in the future, "
            "         choose the earliest valid future year.\n"
            '     * **`start_time`**: string, 12-hour format. It should have leading zeros if the time is less than 10, Ex: 01:00 AM/PM , 05:00 AM/PM. "HH:MM AM/PM"\n'
            '     * **`end_time`**: string, 12-hour format. It should have leading zeros if the time is less than 10, Ex: 01:00 AM/PM , 05:00 AM/PM. "HH:MM AM/PM"\n\n'
            "   - **`by`**: string with the instructor's name(s). If multiple, use ' x ' to separate.\n"
            "   - **`song`**: string with the routine/song name if available, else null.\n"
            "   - **`pricing_info`**: string if pricing is found, else null. Do not include any additional "
            "     tax or service fees. Multiple pricing tiers should be split by a newline character. \n"
            "   - **`timestamp_epoch`**: integer for the workshop's start time as epoch.\n"
            "   - **`artist_id`**: if the instructor matches an entry in the provided artists list, "
            "       use that `artist_id`; otherwise null.\n\n"
            "   **IMPORTANT**:\n"
            "   - If there are multiple distinct ticket types (e.g., 'Hangover' vs 'Gandi baat'), each representing\n"
            "     a different routine or dance item, then create a separate object in `workshop_details` for each.\n"
            "   - If they share the same date/time, use the same `time_details` for each.\n"
            "   - Each workshop object's `song` field should reflect that routine's name (e.g., 'Hangover', 'Gandi baat').\n"
            "   - The `pricing_info` for each object should only show the base price for that ticket type.\n"
            "   - If there are multiple places where workshop details are mentioned in the image, then give more priority any place which says or is similar to workshop details or about event.\n"
            "   - For Dance N Addiciton studio specially , there might be an About event details section that has more accurate info about class timings , song and pricing info particularly the session details section if present.\n"
            "3. Only return a valid JSON object with this exact structure:\n"
            "   ```json\n"
            "   {\n"
            '       "is_workshop": <boolean>,\n'
            '       "workshop_details": [\n'
            "           {\n"
            '               "time_details": {\n'
            '                   "day": <int>,\n'
            '                   "month": <int>,\n'
            '                   "year": <int>,\n'
            '                   "start_time": <string>,\n'
            '                   "end_time": <string>\n'
            "               },\n"
            '               "by": <string or null>,\n'
            '               "song": <string or null>,\n'
            '               "pricing_info": <string or null>,\n'
            '               "timestamp_epoch": <int or null>,\n'
            '               "artist_id": <string or null>\n'
            "           }\n"
            "       ]\n"
            "   }\n"
            "   ```\n\n"
            "4. Do not include extra text outside the JSON.\n"
            "5. Use the provided `artists` data to find any matching `artist_id`. If no match, use null.\n"
            "6. Convert textual date references to numeric day, month, year. If the year is missing, assume future.\n"
            "7. Use 12-hour clock format for times.\n"
            "8. Make `timestamp_epoch` the start date/time in Unix epoch.\n"
            "9. Return only that JSON."
        )

    def _analyze_with_gpt(
        self, screenshot_path: str, artists_data: list = []
    ) -> Optional[WorkshopSummary]:
        """Analyze workshop screenshot using GPT.

        Args:
            screenshot_path: Path to the screenshot file
            artists_data: List of artist data for context

        Returns:
            WorkshopSummary object or None
        """
        try:
            # Read screenshot file
            with open(screenshot_path, "rb") as image_file:
                base64_image = base64.b64encode(image_file.read()).decode("utf-8")

            # Prepare GPT request
            response = self.client.beta.chat.completions.parse(
                model="gpt-4o-2024-11-20",
                messages=[
                    {
                        "role": "system",
                        "content": self._get_gpt_system_content(artists_data),
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
                response_format=WorkshopSummary,
            )

            # Parse GPT response
            analyzed_data = json.loads(response.choices[0].message.content)
            # time.sleep(2)
            # Convert to WorkshopSummary
            return WorkshopSummary(
                is_workshop=analyzed_data.get("is_workshop", False),
                workshop_details=[
                    WorkshopDetails(
                        time_details=TimeDetails(**detail.get("time_details", {})),
                        by=detail.get("by"),
                        song=detail.get("song"),
                        pricing_info=detail.get("pricing_info"),
                        timestamp_epoch=detail.get("timestamp_epoch"),
                        artist_id=detail.get("artist_id"),
                    )
                    for detail in analyzed_data.get("workshop_details", [])
                ],
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
    ):
        """Initialize studio processor."""
        self.workshop_processor = WorkshopProcessor(client, artists, mongo_client)
        self.version = version
        self.position = position
        self.mongo_client = mongo_client

    def process_studio(self, studio: Any, artists_data: list) -> None:
        """Process all workshops for a studio with bulk update."""
        try:
            links = set(x.lower() for x in studio.scrape_links())
            workshop_updates = []
            ignored_links = []
            missing_artists = []
            with tqdm(
                total=len(links),
                desc=f"Processing {studio.config.studio_id}",
                position=self.position,
                leave=False,
            ) as pbar:
                for link in links:
                    workshop_data = self.workshop_processor.process_link(
                        link, studio, self.version, artists_data
                    )

                    if workshop_data:
                        workshop_updates.append(workshop_data)
                        if None in [
                            workshop["artist_id"]
                            for workshop in workshop_data["workshop_details"]
                        ]:
                            missing_artists.append(link)
                    else:
                        ignored_links.append(link)

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
                print(f"Ignored Links for {studio.config.studio_id} : {ignored_links}")
                print(f"Missing artists links for {studio.config.studio_id} : {missing_artists}")
        except Exception as e:
            print(f"Error processing studio {studio.config.studio_id}: {str(e)}")


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
            "dance_n_addiction",
            "dance.inn.bangalore",
            "vins.dance.co",
            "manifestbytmn",
        ],
        help="Specify the studio to populate workshops for",
    )

    return parser.parse_args()


def main():
    """Main execution function."""
    # Parse command-line arguments
    args = parse_arguments()

    # Determine environment
    env = args.env

    # Parse environment configuration
    cfg = config.Config(env=args.env)

    # Initialize clients
    artists = get_artists_data(cfg)
    client = OpenAI(api_key=cfg.openai_api_key)
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
    studios = (
        all_studios
        if args.studio == "all"
        else [
            studio for studio in all_studios if studio.config.studio_id == args.studio
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
            )
            futures.append(
                executor.submit(processor.process_studio, studio, artists_data)
            )

        # Wait for completion and handle errors
        for future in as_completed(futures):
            try:
                future.result()
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
