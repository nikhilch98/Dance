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
    artist_id_list: List[str]
    registration_link: Optional[str]
    registration_link_type: Optional[str]

def manual_populate_workshops(studio_id: str, workshop_details: List[ManualWorkshopEntry], remove_existing_workshops: bool):
    if studio_id not in ["theroyaldancespace", "manifestbytmn", "beinrtribe","goodmove_studios"]:
        return
    mongo_client = DatabaseManager.get_mongo_client("prod")
    workshop_updates = []
    for workshop in workshop_details:
        artist_id_list = sorted(workshop.artist_id_list)
        song = workshop.song.lower() if workshop.song else None
        if song and artist_id_list and not workshop.choreo_insta_link:
            choreo_insta_link_entry = mongo_client["discovery"]["choreo_links"].find_one({"song": song, "artist_id_list": artist_id_list})
            if choreo_insta_link_entry:
                workshop.choreo_insta_link = choreo_insta_link_entry["choreo_insta_link"]

        doc = {
            "payment_link": workshop.registration_link,
            "payment_link_type": workshop.registration_link_type,
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
            "song": song,
            "pricing_info": workshop.pricing_info,
            "artist_id_list": artist_id_list,
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
    HIMANSHU_DULANI_NUMBER = "8296193112"
    RTRIBE_NUMBER = "7338003939"
    GOOD_MOVE_STUDIOS_NUMBER = "9826000000"

    manual_populate_workshops("theroyaldancespace", [
        ManualWorkshopEntry(by="Amisha Jayaram", song="o mama Tetema", pricing_info="Till 19th 800/-\nLater:950/-",
                            event_type=EventType.WORKSHOP, day=21, month=9, year=2025, start_time="03:00 PM",
                            end_time="05:00 PM", choreo_insta_link=None, registration_link=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["amisha_jayaram"],registration_link_type="whatsapp"), 
        ManualWorkshopEntry(by="Kiran J", song="azul", pricing_info="First 15: 999/-\nTill 20th: 1100/-\nOTS: 1300/-",
                            event_type=EventType.WORKSHOP, day=21, month=9, year=2025, start_time="05:00 PM",
                            end_time="07:00 PM", choreo_insta_link=None, registration_link=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["mr.kiranj"],registration_link_type="whatsapp"), 
        ManualWorkshopEntry(by="Kiran J", song="bijuria", pricing_info="First 15: 999/-\nTill 20th: 1100/-\nOTS: 1300/-",
                            event_type=EventType.WORKSHOP, day=21, month=9, year=2025, start_time="07:00 PM",
                            end_time="09:00 PM", choreo_insta_link=None, registration_link=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["mr.kiranj"],registration_link_type="whatsapp"), 
        ManualWorkshopEntry(by="Viveka & Akanksha", song="mayya mayya", pricing_info="Single Class Fee\n799/- till 18th sept\n999/- later \n Both Class 1500/- till 18th Sept\nLater 1700/-",
                            event_type=EventType.WORKSHOP, day=20, month=9, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, registration_link=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=[],registration_link_type="whatsapp"), 
        ManualWorkshopEntry(by="Viveka & Akanksha", song="aavan jaavan", pricing_info="Single Class Fee\n799/- till 18th sept\n999/- later \n Both Class 1500/- till 18th Sept\nLater 1700/-",
                            event_type=EventType.WORKSHOP, day=20, month=9, year=2025, start_time="06:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, registration_link=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=[],registration_link_type="whatsapp"), 
    ], remove_existing_workshops = True)

    # manual_populate_workshops("beinrtribe", [
    #     ManualWorkshopEntry(by="Bindu Bolar", song="chuttamalle", pricing_info="Early bird(Till 6th): 750/-\nLater: 950/-",
    #                         event_type=EventType.WORKSHOP, day=12, month=7, year=2025, start_time="04:00 PM",
    #                         end_time="06:00 PM", choreo_insta_link=None, mobile_number=RTRIBE_NUMBER, artist_id_list=["bindu.bolar22"]),
    #     ManualWorkshopEntry(by="Bindu Bolar", song="kehna hi kya", pricing_info="Early bird(Till 6th): 750/-\nLater: 950/-",
    #                         event_type=EventType.WORKSHOP, day=12, month=7, year=2025, start_time="06:30 PM",
    #                         end_time="08:30 PM", choreo_insta_link=None, mobile_number=RTRIBE_NUMBER, artist_id_list=["bindu.bolar22"]),
    #     ManualWorkshopEntry(by="Shreejee Rawat", song="shake it to the max", pricing_info=None,
    #                         event_type=EventType.WORKSHOP, day=27, month=7, year=2025, start_time="06:30 PM",
    #                         end_time="08:30 PM", choreo_insta_link=None, mobile_number=RTRIBE_NUMBER, artist_id_list=["shreejee._"]),
    # ], remove_existing_workshops = True)
    

    # manual_populate_workshops("goodmove_studios", [
    #     ManualWorkshopEntry(by="", song="Piya re", pricing_info="Early bird: 599/-\nLater: 699/-",
    #                         event_type=EventType.WORKSHOP, day=6, month=7, year=2025, start_time="02:00 PM",
    #                         end_time="04:00 PM", choreo_insta_link=None, registration_link="https://pages.razorpay.com/pl_Qd75qzAYhD7jvq/view", registration_link_type="url", artist_id_list=[]),
    #     ManualWorkshopEntry(by="Rajiv Gupta", song=None, pricing_info="Early bird: 799/-\nLater: 899/-",
    #                         event_type=EventType.WORKSHOP, day=6, month=7, year=2025, start_time="03:00 PM",
    #                         end_time="05:00 PM", choreo_insta_link=None, registration_link="https://pages.razorpay.com/pl_Qkg2n9FEXYOdXR/view", registration_link_type="url", artist_id_list=["rajivkrishnagupta"]),
    #     ManualWorkshopEntry(by="Rajiv Gupta", song=None, pricing_info="Early bird: 799/-\nLater: 899/-",
    #                         event_type=EventType.WORKSHOP, day=6, month=7, year=2025, start_time="06:00 PM",
    #                         end_time="08:00 PM", choreo_insta_link=None, registration_link="https://pages.razorpay.com/pl_Qkg2n9FEXYOdXR/view", registration_link_type="url", artist_id_list=["rajivkrishnagupta"]),
    # ], remove_existing_workshops = True)






if __name__ == "__main__":
    main()