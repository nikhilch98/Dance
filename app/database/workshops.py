"""Workshop database operations."""

from datetime import datetime, timedelta
import re
from typing import List, Optional, Dict
from collections import defaultdict

from utils.utils import (
    get_mongo_client,
    get_formatted_date,
    get_formatted_date_with_day,
    get_formatted_time,
    get_timestamp_epoch,
    get_formatted_date_without_day,
)
from app.models.workshops import (
    EventDetails,
    WorkshopListItem,
    Artist,
    Studio,
    WorkshopSession,
    DaySchedule,
    CategorizedWorkshopResponse,
)


def format_workshop_data(workshop: dict) -> List[EventDetails]:
    """Process workshop data from the database."""
    event_details = []
    for time_details in workshop["time_details"]:
        if workshop["event_type"] not in ["workshop", "intensive"]:
            continue
        date_without_day = get_formatted_date_without_day(time_details)
        if date_without_day is None:
            print(f"Skipping workshop {workshop['uuid']} due to missing data in time_details", time_details)
            continue
            
        # Use artist_id_list directly
        artist_id_list = workshop.get("artist_id_list", [])
        date_with_day, time_day_full_string = get_formatted_date_with_day(time_details)
        event_details.append(EventDetails(
            mongo_id=str(workshop["_id"]),
            payment_link=workshop["payment_link"],
            studio_id=workshop["studio_id"],
            uuid=workshop["uuid"],
            event_type=workshop["event_type"],
            artist_name=workshop["by"],
            artist_id_list=artist_id_list,
            song=workshop["song"],
            pricing_info=workshop["pricing_info"],
            updated_at=workshop["updated_at"],
            date_without_day=date_without_day,
            date_with_day=date_with_day,
            time_str=get_formatted_time(time_details),
            timestamp_epoch=get_timestamp_epoch(time_details),
            time_year=time_details["year"],
            time_month=time_details["month"],
            time_day=time_details["day"],
            time_day_full_string=time_day_full_string,
            choreo_insta_link=workshop["choreo_insta_link"],
        ))
    return event_details


class DatabaseOperations:
    """Database operations for the application."""

    @staticmethod
    def get_workshops(
        studio_id: Optional[str] = None,
        event_type_blacklist: Optional[List[str]] = ["regulars"],
        sort_by_timestamp: bool = True,
        song_whitelist: Optional[List[str]] = [],
        artist_id_whitelist: Optional[List[str]] = [],
        search_query: Optional[str] = None
    ) -> List[EventDetails]:
        """Fetch all workshops from the database.

        Returns:
            List of workshops with formatted details
        """
        client = get_mongo_client()
        filter = {}
        if studio_id:
            filter["studio_id"] = studio_id
        if event_type_blacklist:
            filter["event_type"] = {"$nin": event_type_blacklist}
        if song_whitelist:
            filter["song"] = {"$in": song_whitelist}
        if artist_id_whitelist:
            # Only use artist_id_list field
            filter["artist_id_list"] = {"$in": artist_id_whitelist}
        if search_query:
            pattern = re.compile(re.escape(search_query.strip()), re.IGNORECASE)
            filter["$or"] = [
                {"song": {"$regex": pattern}},
                {"by": {"$regex": pattern}}
            ]

        # Build a mapping from studio_id to studio_name
        workshops_cursor: List[EventDetails] = []
        for workshop in list(client["discovery"]["workshops_v2"].find(filter)):
            workshops_cursor += format_workshop_data(workshop)
        if sort_by_timestamp:
            workshops_cursor.sort(key=lambda x: x.timestamp_epoch)
        return workshops_cursor

    def get_all_workshops(search_query: Optional[str] = None) -> List[WorkshopListItem]:
        """Fetch all workshops from the database."""
        client = get_mongo_client()
        studios = list(client["discovery"]["studios"].find({}))
        studios_map = {studio["studio_id"]: studio["studio_name"] for studio in studios}
        
        # Build a mapping from artist_id to artist image_url
        artists = list(client["discovery"]["artists_v2"].find({}))
        artists_map = {artist["artist_id"]: artist.get("image_url") for artist in artists}

        def format_artist_name(artist_id_list, extracted_artist_name) -> str:
            artist_names = []
            for artist_id in artist_id_list:
                if artist_id not in artists_map:
                    continue
                name = artists_map[artist_id]["artist_name"]
                artist_names += [name]
            if not artist_names:
                return extracted_artist_name
            if len(artist_names) == 1:
                return artist_names[0]
            return " X ".join([name.split()[0] for name in artist_names])

        workshops =  [
            WorkshopListItem(
            uuid=workshop.uuid,
            payment_link=workshop.payment_link,
            studio_id=workshop.studio_id,
            studio_name=studios_map[workshop.studio_id],
            updated_at=workshop.updated_at,
            by=format_artist_name(workshop.artist_id_list, workshop.artist_name),
            song=workshop.song,
            pricing_info=workshop.pricing_info,
            timestamp_epoch=workshop.timestamp_epoch,
            artist_id_list=workshop.artist_id_list,
            artist_image_urls=[artists_map.get(artist_id) for artist_id in workshop.artist_id_list] if workshop.artist_id_list else [],
            date=workshop.date_with_day,
            time=workshop.time_str,
            event_type=workshop.event_type,
            choreo_insta_link=workshop.choreo_insta_link,
        )
            for workshop in DatabaseOperations.get_workshops(sort_by_timestamp=True, search_query=search_query)
        ]
        return workshops

    @staticmethod
    def get_studios() -> List[Studio]:
        """Fetch all active studios from the database.

        Returns:
            List of studios with active workshops
        """
        client = get_mongo_client()
        return [
            {
                "id": studio["studio_id"],
                "name": studio["studio_name"],
                "image_url": studio.get("image_url"),
                "instagram_link": studio["instagram_link"],
            }
            for studio in client["discovery"]["studios"].find({})
        ]

    @staticmethod
    def get_artists(has_workshops: Optional[bool] = None) -> List[Artist]:
        """Fetch all active artists from the database.

        Returns:
            List of artists with active workshops
        """
        client = get_mongo_client()
        # Get artists that appear in artist_id_list arrays
        artists_with_workshops = set()
        for workshop in client["discovery"]["workshops_v2"].find({}, {"artist_id_list": 1}):
            artist_list = workshop.get("artist_id_list", [])
            if artist_list:
                artists_with_workshops.update(artist_list)
        
        all_artists = list(client["discovery"]["artists_v2"].find({}))
        
        return sorted([
            {
                "id": artist["artist_id"],
                "name": artist["artist_name"],
                "image_url": artist.get("image_url"),
                "instagram_link": artist["instagram_link"],
            }
            for artist in all_artists if has_workshops is None or (has_workshops and artist["artist_id"] in artists_with_workshops) or (not has_workshops and artist["artist_id"] not in artists_with_workshops)
        ], key=lambda x: x["name"])

    @staticmethod
    def get_workshops_by_artist(artist_id: str) -> List[WorkshopSession]:
        """Fetch workshops for a specific artist.

        Args:
            artist_id: Unique identifier for the artist

        Returns:
            List of workshop sessions sorted by timestamp
        """
        client = get_mongo_client()
        workshops = []
        
        # Find workshops where the artist_id is in the artist_id_list
        workshops_cursor = client["discovery"]["workshops_v2"].find({
            "artist_id_list": artist_id
        })
        
        for workshop in workshops_cursor:
            for time_detail in workshop.get("time_details", []):
                if not time_detail:
                    continue
                    
                workshops.append(
                    WorkshopSession(
                        date=get_formatted_date_with_day(time_detail)[0],
                        time=get_formatted_time(time_detail),
                        song=workshop.get("song"),
                        studio_id=workshop.get("studio_id"),
                        artist_id_list=workshop.get("artist_id_list", []),
                        artist=workshop.get("by"),
                        payment_link=workshop.get("payment_link"),
                        pricing_info=workshop.get("pricing_info"),
                        timestamp_epoch=get_timestamp_epoch(time_detail),
                        event_type=workshop.get("event_type"),
                        choreo_insta_link=workshop.get("choreo_insta_link"),
                    )
                )

        return sorted(workshops, key=lambda x: x.timestamp_epoch)

    @staticmethod
    def get_all_workshops_categorized(studio_id: Optional[str] = None) -> CategorizedWorkshopResponse:
        """Fetch workshops for a specific studio grouped by this week (daily) and post this week.

        Args:
            studio_id: Unique identifier for the studio

        Returns:
            Object containing 'this_week' (list of daily schedules) and 'post_this_week' workshops.
        """
        client = get_mongo_client()
        studios = list(client["discovery"]["studios"].find({}))
        studios_map = {studio["studio_id"]: studio["studio_name"] for studio in studios}
        
        # Build a mapping from artist_id to artist image_url
        artists = list(client["discovery"]["artists_v2"].find({}))
        artists_map = {artist["artist_id"]: artist for artist in artists}

        temp_this_week: List[EventDetails] = []
        temp_post_this_week: List[EventDetails] = []

        # Calculate current week boundaries (Monday to Sunday)
        today = datetime.now().date()
        start_of_week = today - timedelta(days=today.weekday())
        end_of_week = start_of_week + timedelta(days=6)
        if studio_id:
            workshops_cursor: List[EventDetails] = DatabaseOperations.get_workshops(studio_id=studio_id)
        else:
            workshops_cursor: List[EventDetails] = DatabaseOperations.get_workshops()

        for workshop in workshops_cursor:
            # Categorize by week using time_details
            try:
                workshop_date = datetime(
                    year=workshop.time_year,
                    month=workshop.time_month,
                    day=workshop.time_day,
                ).date()
            except KeyError as e:
                print(
                    f"Skipping session due to incomplete time_details: {e} in {workshop}"
                )
                continue

            if start_of_week <= workshop_date <= end_of_week:
                temp_this_week.append(workshop)
            elif workshop_date > end_of_week:
                temp_post_this_week.append(workshop)

        # Process 'this_week' workshops into daily structure
        this_week_by_day: Dict[str, List[EventDetails]] = {}
        for workshop in temp_this_week:
            # TODO: What happends if the day is not in the list? when day is not present , it is None
            weekday = workshop.time_day_full_string
            if weekday not in this_week_by_day:
                this_week_by_day[weekday] = []
            this_week_by_day[weekday].append(workshop)

        final_this_week = []
        days_order = [
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday",
        ]

        def format_artist_name(artist_id_list, extracted_artist_name) -> str:
            artist_names = []
            for artist_id in artist_id_list:
                if artist_id not in artists_map:
                    continue
                name = artists_map[artist_id]["artist_name"]
                artist_names += [name]
            if not artist_names:
                return extracted_artist_name
            if len(artist_names) == 1:
                return artist_names[0]
            return " X ".join([name.split()[0] for name in artist_names])

        for day in days_order:
            if not this_week_by_day.get(day,[]):
                continue
            sorted_workshops_raw = sorted(
                this_week_by_day[day],
                key=lambda x: x.timestamp_epoch, 
            )
            final_this_week.append(
                DaySchedule(
                    day=day,
                    workshops=[WorkshopListItem(
                        uuid=x.uuid,
                        payment_link=x.payment_link,
                        studio_id=x.studio_id,
                        studio_name=studios_map[x.studio_id],
                        updated_at=x.updated_at,
                        by=format_artist_name(x.artist_id_list, x.artist_name),
                        song=x.song,
                        pricing_info=x.pricing_info,
                        timestamp_epoch=x.timestamp_epoch,
                        artist_id_list=x.artist_id_list,
                        artist_image_urls=[artists_map.get(artist_id,{}).get("image_url") for artist_id in x.artist_id_list] if x.artist_id_list else [],
                        date=x.date_with_day,
                        time=x.time_str,
                        event_type=x.event_type,
                        choreo_insta_link=x.choreo_insta_link,
                    ) for x in sorted_workshops_raw]
                )
            )

        # Sort 'post_this_week' workshops chronologically using timestamp_epoch

        sorted_post_this_week = [WorkshopListItem(
                        uuid=x.uuid,
                        payment_link=x.payment_link,
                        studio_id=x.studio_id,
                        studio_name=studios_map[x.studio_id],
                        updated_at=x.updated_at,
                        by=format_artist_name(x.artist_id_list, x.artist_name),
                        song=x.song,
                        pricing_info=x.pricing_info,
                        timestamp_epoch=x.timestamp_epoch,
                        artist_id_list=x.artist_id_list,
                        artist_image_urls=[artists_map.get(artist_id,{}).get("image_url") for artist_id in x.artist_id_list] if x.artist_id_list else [],
                        date=x.date_with_day,
                        time=x.time_str,
                        event_type=x.event_type,
                        choreo_insta_link=x.choreo_insta_link,
                    ) for x in sorted(
            temp_post_this_week,
            key=lambda x: x.timestamp_epoch, 
        )]
        return CategorizedWorkshopResponse(
            this_week=final_this_week, post_this_week=sorted_post_this_week
        )

    @staticmethod
    def get_workshops_missing_songs():
        """Get workshops that are missing song information."""
        client = get_mongo_client()
        
        # Find workshops where song_name is null, empty, or missing
        workshops = client["dance_app"]["workshops"].find({
            "$or": [
                {"song_name": {"$exists": False}},
                {"song_name": None},
                {"song_name": ""},
                {"song_name": {"$regex": "^\\s*$"}}  # Only whitespace
            ]
        })
        
        return list(workshops)

    @staticmethod
    def get_total_workshop_count() -> int:
        """Get the total count of workshops in the database."""
        client = get_mongo_client()
        
        return client["discovery"]["workshops_v2"].count_documents({})