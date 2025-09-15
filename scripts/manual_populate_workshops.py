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
    workshop_uuid: str

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
            "uuid": workshop.workshop_uuid,
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
    AMULYA_NUMBER = "8197127284"

    manual_populate_workshops("theroyaldancespace", [
        # Amisha's workshop with time-based tiered pricing
        ManualWorkshopEntry(by="Amisha Jayaram", song="o mama Tetema",
                            pricing_info="Early Bird (Till 19th Sept): ₹800/-\nStandard (20th-21st Sept): ₹950/-",
                            event_type=EventType.WORKSHOP, day=21, month=9, year=2025, start_time="03:00 PM",
                            end_time="05:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["amisha_jayaram"],registration_link_type="nachna", workshop_uuid="theroyaldancespace/amisha_jayaram-workshop_21_9_2025_o_mama_tetema"),

        # Kiran J's workshops with tiered pricing
        ManualWorkshopEntry(by="Kiran J", song="aavan jaavan",
                            pricing_info="First 15 spots: ₹999/-\n16-20 spots (till 20th): ₹1100/-\nOTS (after 20th): ₹1300/-\nBUNDLE:Evening Double:KIRAN_DOUBLE:theroyaldancespace/mr.kiranj-workshop_21_9_2025_azul,theroyaldancespace/mr.kiranj-workshop_21_9_2025_bijuria:1799:INR:Save ₹400 on both classes",
                            event_type=EventType.WORKSHOP, day=21, month=9, year=2025, start_time="05:00 PM",
                            end_time="07:00 PM", choreo_insta_link=None, registration_link=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["mr.kiranj"],registration_link_type="whatsapp", workshop_uuid="theroyaldancespace/mr.kiranj-workshop_21_9_2025_azul"),

        ManualWorkshopEntry(by="Kiran J", song="bijuria",
                            pricing_info="First 15 spots: ₹999/-\n16-20 spots (till 20th): ₹1100/-\nOTS (after 20th): ₹1300/-\nBUNDLE:Evening Double:KIRAN_DOUBLE:theroyaldancespace/mr.kiranj-workshop_21_9_2025_azul,theroyaldancespace/mr.kiranj-workshop_21_9_2025_bijuria:1799:INR:Save ₹400 on both classes",
                            event_type=EventType.WORKSHOP, day=21, month=9, year=2025, start_time="07:00 PM",
                            end_time="09:00 PM", choreo_insta_link=None, registration_link=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["mr.kiranj"],registration_link_type="whatsapp", workshop_uuid="theroyaldancespace/mr.kiranj-workshop_21_9_2025_bijuria"),

        # Vivek & Aakanksha's workshops with time-based tiered pricing and bundle option
        ManualWorkshopEntry(by="Vivek & Aakanksha", song="mayya mayya",
                            pricing_info="Early Bird (Till 18th Sept): ₹799/-\nStandard (19th-20th Sept): ₹999/-\nBUNDLE: Two Workshops Bundle Package: TWO_WORKSHOPS_BUNDLE: theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_mayya,theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_aavan: 1500: INR: Save ₹98 on both workshops (₹799 each = ₹1598 total)",
                            event_type=EventType.WORKSHOP, day=20, month=9, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["vicky__pedia","aakanksha5678"],registration_link_type="nachna", workshop_uuid="theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_mayya"),

        ManualWorkshopEntry(by="Vivek & Aakanksha", song="aavan jaavan",
                            pricing_info="Early Bird (Till 18th Sept): ₹799/-\nStandard (19th-20th Sept): ₹999/-\nBUNDLE: Two Workshops Bundle Package: TWO_WORKSHOPS_BUNDLE: theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_mayya,theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_aavan: 1500: INR: Save ₹98 on both workshops (₹799 each = ₹1598 total)",
                            event_type=EventType.WORKSHOP, day=20, month=9, year=2025, start_time="06:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["vicky__pedia","aakanksha5678"],registration_link_type="nachna", workshop_uuid="theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_aavan"),
        ManualWorkshopEntry(by="Desi Clans", song="ABCD 5.0 - Garba & Dandiya",
                            pricing_info="Early bird : 499/-",
                            event_type=EventType.WORKSHOP, day=14, month=9, year=2025, start_time="05:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, registration_link="https://in.bookmyshow.com/events/abcd-5-0-garba-dandiya-workshop/ET00456813", artist_id_list=["desiclans"],registration_link_type="url", workshop_uuid="theroyaldancespace_sanksruti_garba_workshop_14_9_2025_abcd_5_0_garba_dandiya"),
        ManualWorkshopEntry(by="Desi Clans", song="ABCD 5.0 - Garba & Dandiya",
                            pricing_info="Early bird : 499/-",
                            event_type=EventType.WORKSHOP, day=20, month=9, year=2025, start_time="05:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, registration_link="https://in.bookmyshow.com/events/abcd-5-0-garba-dandiya-workshop/ET00456813", artist_id_list=["desiclans"],registration_link_type="url", workshop_uuid="theroyaldancespace_sanksruti_garba_workshop_14_9_2025_abcd_5_0_garba_dandiya"),
        ManualWorkshopEntry(by="Sankruti Garba", song="Garba",
                            pricing_info="1499/-",
                            event_type=EventType.WORKSHOP, day=13, month=9, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, registration_link="sanskrutigarba.in", artist_id_list=["sanskrutigarba"],registration_link_type="url", workshop_uuid="theroyaldancespace_sanksruti_garba_workshop_13_9_2025_garba"),
        ManualWorkshopEntry(by="Sankruti Garba", song="Garba",
                            pricing_info="1499/-",
                            event_type=EventType.WORKSHOP, day=14, month=9, year=2025, start_time="06:30 PM",
                            end_time="08:30 PM", choreo_insta_link=None, registration_link="sanskrutigarba.in", artist_id_list=["sanskrutigarba"],registration_link_type="url", workshop_uuid="theroyaldancespace_sanksruti_garba_workshop_13_9_2025_garba"),
        ManualWorkshopEntry(by="Gaurav & Yana", song="Hai Rama",
                            pricing_info="Early Bird : 799/-\nCouple: 1799/-",
                            event_type=EventType.WORKSHOP, day=3, month=10, year=2025, start_time="07:00 PM",
                            end_time="09:00 PM", choreo_insta_link=None, registration_link="https://www.gauravandyana.com/event-details/4th-october-bangalore-hai-rama-choreography-workshop-by-g-y", artist_id_list=["gauravandyana"],registration_link_type="url", workshop_uuid="theroyaldancespace_gaurav_yana_workshop_3_10_2025_hai_rama"),
      
    ], remove_existing_workshops = True)

    manual_populate_workshops("beinrtribe", [
        ManualWorkshopEntry(by="Sanket Panchal", song="Shaky Shaky",
                            pricing_info="950/-",
                            event_type=EventType.WORKSHOP, day=21, month=9, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["sanket_panchal25"],registration_link_type="nachna", workshop_uuid="beinrtribe_sanket_panchal25_workshop_21_9_2025_shaky_shaky"),
    ], remove_existing_workshops = True)
    

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