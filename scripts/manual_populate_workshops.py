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
    is_archived: bool = False

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
            "is_archived": workshop.is_archived,
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
        ManualWorkshopEntry(is_archived=True, by="Amisha Jayaram", song="o mama Tetema",
                            pricing_info="Early Bird (Till 19th Sept): ₹950/-\nStandard (20th-21st Sept): ₹950/-",
                            event_type=EventType.WORKSHOP, day=21, month=9, year=2025, start_time="03:00 PM",
                            end_time="05:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["amisha_jayaram"],registration_link_type="nachna", workshop_uuid="theroyaldancespace_amisha_jayaram-workshop_21_9_2025_o_mama_tetema"),
        # Vivek & Aakanksha's workshops with time-based tiered pricing and bundle option
        ManualWorkshopEntry(is_archived=True, by="Vivek & Aakanksha", song="mayya mayya",
                            pricing_info="Early Bird (Till 18th Sept): ₹799/-\nStandard (19th-20th Sept): ₹999/-\nBUNDLE: Two Workshops Bundle Package: TWO_WORKSHOPS_BUNDLE: theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_mayya,theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_aavan: 1500: INR: Save ₹98 on both workshops (₹799 each = ₹1598 total)",
                            event_type=EventType.WORKSHOP, day=20, month=9, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["vicky__pedia","aakanksha5678"],registration_link_type="nachna", workshop_uuid="theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_mayya"),
        ManualWorkshopEntry(is_archived=True, by="Vivek & Aakanksha", song="aavan jaavan",
                            pricing_info="Early Bird (Till 20th Sept): ₹999/-\nStandard (19th-20th Sept): ₹999/-\nBUNDLE: Two Workshops Bundle Package: TWO_WORKSHOPS_BUNDLE: theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_mayya,theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_aavan: 1500: INR: Save ₹98 on both workshops (₹799 each = ₹1598 total)",
                            event_type=EventType.WORKSHOP, day=20, month=9, year=2025, start_time="06:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["vicky__pedia","aakanksha5678"],registration_link_type="nachna", workshop_uuid="theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_aavan"),
        ############################
        
        ManualWorkshopEntry(is_archived=False, by="Gaurav & Yana", song="Hai Rama",
                            pricing_info="Early Bird : 799/-\nCouple: 1799/-",
                            event_type=EventType.WORKSHOP, day=3, month=10, year=2025, start_time="07:00 PM",
                            end_time="09:00 PM", choreo_insta_link=None, registration_link="https://www.gauravandyana.com/event-details/4th-october-bangalore-hai-rama-choreography-workshop-by-g-y", artist_id_list=["gauravandyana"],registration_link_type="url", workshop_uuid="theroyaldancespace_gaurav_yana_workshop_3_10_2025_hai_rama"),

        ManualWorkshopEntry(is_archived=False, by="Ashish Dubey", song="Ucha Lamba Kad",
                            pricing_info="Early Bird (Till 26th Sept): ₹799/-\nStandard (27th-27th Sept): ₹999/-",
                            event_type=EventType.WORKSHOP, day=27, month=9, year=2025, start_time="06:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["ashish.dubeyyyy"],registration_link_type="nachna", workshop_uuid="theroyaldancespace_aashish_dubeyy_workshop_27_9_2025_ucha_lamba_kad"),

        ManualWorkshopEntry(is_archived=False, by="Sanaa", song="Toxic - Britney Spears",
                            pricing_info="1699/-",
                            event_type=EventType.WORKSHOP, day=28, month=9, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, registration_link="rzp.io/l/soulworkshop25", artist_id_list=["sanaabanana_"],registration_link_type="url", workshop_uuid="theroyaldancespace_sanaa_banana_workshop_28_9_2025_toxic_britney_spears"),

        ManualWorkshopEntry(is_archived=False, by="Team Naach", song="Mere khayalon ki mallika",
                            pricing_info="1000/-",
                            event_type=EventType.WORKSHOP, day=28, month=9, year=2025, start_time="12:00 PM",
                            end_time="03:00 PM", choreo_insta_link=None, registration_link="teamnaach.in", artist_id_list=["teamnaach"],registration_link_type="url", workshop_uuid="theroyaldancespace_teamnaach_workshop_28_9_2025_mere_khayalon_ki_mallika"),

        ManualWorkshopEntry(is_archived=False, by="Team Naach", song="Tu",
                            pricing_info="1000/-",
                            event_type=EventType.WORKSHOP, day=28, month=9, year=2025, start_time="06:30 PM",
                            end_time="09:30 PM", choreo_insta_link=None, registration_link="teamnaach.in", artist_id_list=["teamnaach"],registration_link_type="url", workshop_uuid="theroyaldancespace_teamnaach_workshop_28_9_2025_tu"),
        ManualWorkshopEntry(is_archived=False, by="Sonali Bhadauria", song="To be decided",
                            pricing_info="1000/-",
                            event_type=EventType.WORKSHOP, day=12, month=10, year=2025, start_time="06:00 PM",
                            end_time="08:00 PM", choreo_insta_link=None, registration_link=ROYAL_DANCE_STUDIO_NUMBER, artist_id_list=["sonali.bhadauria"],registration_link_type="whatsapp", workshop_uuid="theroyal_dance_space_sonali_bhadauria_workshop_12_10_2025_to_be_decided"),
    ], remove_existing_workshops = True)

    manual_populate_workshops("beinrtribe", [
        #################### Dont delete workshops in between these lines ####################
        ManualWorkshopEntry(is_archived=True, by="Sanket Panchal", song="Shaky Shaky",
                            pricing_info="Early Bird (Till 19th Sept): ₹900/-\nStandard (20th-21st Sept): ₹900/-",
                            event_type=EventType.WORKSHOP, day=21, month=9, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["sanket_panchal25"],registration_link_type="nachna", workshop_uuid="beinrtribe_sanket_panchal25_workshop_21_9_2025_shaky_shaky"),
        #################### Dont delete workshops in between these lines ####################

        ManualWorkshopEntry(is_archived=False, by="Chirag Gupta", song="oh mama tetema",
                            pricing_info="Pre-registration: ₹950/-\nOn The Spot: ₹1200",
                            event_type=EventType.WORKSHOP, day=29, month=11, year=2025, start_time="05:00 PM",
                            end_time="07:00 PM", choreo_insta_link=None, registration_link=RTRIBE_NUMBER, artist_id_list=["chirag_guptaaaa"],registration_link_type="whatsapp", workshop_uuid="beinrtribe_chirag_gupta_workshop_29_11_2025_oh_mama_tetema"),
        ManualWorkshopEntry(is_archived=False, by="Chirag Gupta", song="shut up and bounce",
                            pricing_info="Pre-registration: ₹950/-\nOn The Spot: ₹1200",
                            event_type=EventType.WORKSHOP, day=29, month=11, year=2025, start_time="07:30 PM",
                            end_time="09:30 PM", choreo_insta_link=None, registration_link=RTRIBE_NUMBER, artist_id_list=["chirag_guptaaaa"],registration_link_type="whatsapp", workshop_uuid="beinrtribe_chirag_gupta_workshop_29_11_2025_shut_up_and_bounce"),
        
        ManualWorkshopEntry(is_archived=False, by="Aditya Tripathi", song="shake body",
                            pricing_info="Pre-registration: ₹950/-\nOn The Spot: ₹1200",
                            event_type=EventType.WORKSHOP, day=30, month=11, year=2025, start_time="02:00 PM",
                            end_time="04:00 PM", choreo_insta_link=None, registration_link=RTRIBE_NUMBER, artist_id_list=["adityatripathiii__"],registration_link_type="whatsapp", workshop_uuid="beinrtribe_aditya_tripathi_workshop_30_11_2025_shake_body"),

        ManualWorkshopEntry(is_archived=False, by="Dharmik Samani", song="chhan ke mohalla",
                            pricing_info="Single Class: 1100/-\nTwo Classes: 2000/-\nThree Classes: 2700/-",
                            event_type=EventType.WORKSHOP, day=7, month=12, year=2025, start_time="01:00 PM",
                            end_time="03:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["dharmiksamani"],registration_link_type="nachna", workshop_uuid="beinrtribe_dharmik_samani_workshop_7_12_2025_chhan_ke_mohalla"),
        ManualWorkshopEntry(is_archived=False, by="Dharmik Samani", song="dhoonde akhiyaan",
                            pricing_info="Single Class: 1100/-\nTwo Classes: 2000/-\nThree Classes: 2700/-",
                            event_type=EventType.WORKSHOP, day=7, month=12, year=2025, start_time="04:00 PM",
                            end_time="06:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["dharmiksamani"],registration_link_type="nachna", workshop_uuid="beinrtribe_dharmik_samani_workshop_7_12_2025_dhoonde_akhiyaan"),
        ManualWorkshopEntry(is_archived=False, by="Dharmik Samani", song="kukkad",
                            pricing_info="Single Class: 1100/-\nTwo Classes: 2000/-\nThree Classes: 2700/-",
                            event_type=EventType.WORKSHOP, day=7, month=12, year=2025, start_time="07:00 PM",
                            end_time="09:00 PM", choreo_insta_link=None, registration_link="a", artist_id_list=["dharmiksamani"],registration_link_type="nachna", workshop_uuid="beinrtribe_dharmik_samani_workshop_7_12_2025_kukkad"),
    ], remove_existing_workshops = True)






if __name__ == "__main__":
    main()