from typing import List, Optional
from pydantic import BaseModel
from enum import Enum
import time
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.utils import DatabaseManager


class EventType(Enum):
    WORKSHOP = "workshop"
    INTENSIVE = "intensive"
    REGULARS = "regulars"

class ManualWorkshopEntry(BaseModel):
    by: str
    song: Optional[str]
    pricing_info: Optional[str]
    event_type: EventType
    day: int
    month: int
    year: int
    start_time: str ## "HH:MM AM/PM"
    end_time: str ## "HH:MM AM/PM"
    choreo_insta_link: Optional[str]
    mobile_number: str
    artist_id_list: List[str]

def manual_populate_workshops(studio_id: str, workshop_details: List[ManualWorkshopEntry], remove_existing_workshops: bool):
    if studio_id not in ["theroyaldancespace", "manifestbytmn"]:
        return
    mongo_client = DatabaseManager.get_mongo_client("prod")
    workshop_updates = []
    for workshop in workshop_details:
        doc = {
            "payment_link": workshop.mobile_number,
            "payment_link_type": "whatsapp",
            "studio_id": studio_id,
            "uuid": f"{studio_id}/{workshop.by.lower()}-{workshop.event_type.value.lower()}_{workshop.day}_{workshop.month}_{workshop.year}",
            "event_type": workshop.event_type.value.lower(),
            "time_details": [
                {
                    "day": workshop.day,
                    "month": workshop.month,
                    "year": workshop.year,
                    "start_time": workshop.start_time,
                    "end_time": workshop.end_time
                }
            ],
            "by": workshop.by,
            "song": workshop.song.lower(),
            "pricing_info": workshop.pricing_info,
            "artist_id_list": workshop.artist_id_list,
            "updated_at":  time.time(),
            "version": 1,
            "choreo_insta_link": workshop.choreo_insta_link,
        }
        workshop_updates.append(doc)
    if remove_existing_workshops:
        delete_result = mongo_client["discovery"][
            "workshops_v2"
        ].delete_many({"studio_id": studio_id})
        print(
            f"\nDeleted {delete_result.deleted_count} existing workshops for {studio_id}"
        )
    insert_result = mongo_client["discovery"][
        "workshops_v2"
    ].insert_many(workshop_updates)
    print(
        f"Inserted {len(insert_result.inserted_ids)} new workshops for {studio_id}"
    )

def main():

    ROYAL_DANCE_STUDIO_NUMBER = "7304733374"
    THANGAAT_GARBA_NUMBER = "7021211630"
    NATYA_SOCIAL_NUMBER = "9892652774"

    manual_populate_workshops("theroyaldancespace", [
        ManualWorkshopEntry(by="Pooja", song="the way i are (jazz)", pricing_info="Till 19th June: 899/-\n Later: 999/-",
                            event_type=EventType.WORKSHOP, day=21, month=6, year=2025, start_time="01:00 PM",
                            end_time="03:00 PM", choreo_insta_link=None, mobile_number=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["poojapurohith_"]),
        ManualWorkshopEntry(by="Risparna", song="jiya jale", pricing_info="Till 19th June: 599/-\n Later: 799/-",
                            event_type=EventType.WORKSHOP, day=21, month=6, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, mobile_number=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["rishhparnaa"]),
        ManualWorkshopEntry(by="Seerat Madan", song="rajvaadi odhni", pricing_info="Till 19th June: 899/-\n Later: 999/-",
                            event_type=EventType.WORKSHOP, day=21, month=6, year=2025, start_time="06:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, mobile_number=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["always_on_taal"]),
        ManualWorkshopEntry(by="Wehzan", song="say what", pricing_info="Till 19th June: 899/-\n Later: 999/-",
                            event_type=EventType.WORKSHOP, day=21, month=6, year=2025, start_time="08:00 PM",
                            end_time="10:00 PM", choreo_insta_link=None, mobile_number=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["wehzan"]),
        ManualWorkshopEntry(by="Abhishek", song="tuta pull wahan", pricing_info=None,
                            event_type=EventType.WORKSHOP, day=22, month=6, year=2025, start_time="12:00 PM",
                            end_time="02:00 PM", choreo_insta_link=None, mobile_number=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["abhishek_vernekar"]),
        ManualWorkshopEntry(by="Thangaat Garba", song="bolly garba", pricing_info="Till 21st June 9PM: 800/-\n Later: 950/-",
                            event_type=EventType.WORKSHOP, day=22, month=6, year=2025, start_time="02:00 PM",
                            end_time="04:00 PM", choreo_insta_link=None, mobile_number=THANGAAT_GARBA_NUMBER, artist_id_list=["thangaatgarba"]),
        ManualWorkshopEntry(by="Seerat Madan", song="tere bin", pricing_info="Till 19th June: 899/-\n Later: 999/-",
                            event_type=EventType.WORKSHOP, day=22, month=6, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, mobile_number=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["always_on_taal"]),
        ManualWorkshopEntry(by="Swady Dinesh", song="bamboo hips don't lie", pricing_info="Till 19th June: 899/-\n Later: 999/-",
                            event_type=EventType.WORKSHOP, day=22, month=6, year=2025, start_time="06:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, mobile_number=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["swady_dinesh"]),
    ], remove_existing_workshops = True)



    manual_populate_workshops("manifestbytmn", [
        ManualWorkshopEntry(by="Vinayak Ghoshal", song="dekha ek khwab", pricing_info=None,
                            event_type=EventType.WORKSHOP, day=15, month=6, year=2025, start_time="02:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, mobile_number=NATYA_SOCIAL_NUMBER, artist_id_list=["natyasocial"]),
        ManualWorkshopEntry(by="Vinayak Ghoshal", song="mera dadla", pricing_info=None,
                            event_type=EventType.WORKSHOP, day=15, month=6, year=2025, start_time="06:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, mobile_number=NATYA_SOCIAL_NUMBER, artist_id_list=["natyasocial"]),
    ], remove_existing_workshops = False)




if __name__ == "__main__":
    main()