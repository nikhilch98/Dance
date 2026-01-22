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


# AI Model Configuration
AI_MODEL_VERSIONS = {
    "openai": "gpt-5-mini",
    "gemini": "gemini-2.5-flash"
}
AI_REQUEST_DELAY = {
    "openai": 2,  # seconds between requests for OpenAI
    "gemini": 0.5  # seconds between requests for Gemini
}

# Studio-specific extraction hints for AI prompt
STUDIO_EXTRACTION_HINTS = {
    "manifestbytmn": """
═══════════════════════════════════════════════════════════════
STUDIO: MANIFEST BY TMN
═══════════════════════════════════════════════════════════════

WHERE TO LOOK:
1. Session selection cards (RIGHT side) → PRIMARY SOURCE
2. Header "by {Artist Name}" → Artist name
3. Poster (LEFT) → IGNORE, use for validation only

WHAT TO EXTRACT:
• Each session card WITH A UNIQUE SONG = ONE event_details object
• Card contains: Song name (title), Date, Time, Duration, Price
• "Phase 1 (Active)" = session is available

⚠️ COMBO/BUNDLE HANDLING - CRITICAL:
• "Both Sessions", "Combo", "Full Day" options are PRICING BUNDLES
• They are NOT separate workshops - do NOT create event_details for combos
• If you see 2 song sessions + 1 combo option → create ONLY 2 event_details
• Include combo price in EACH individual workshop's pricing_info

EXAMPLE:
Page shows: "Pal Pal" (₹850), "Desi Girl" (₹850), "Both Sessions" (₹1500)
→ Create 2 event_details (NOT 3):
  - event_details[0]: song="pal pal", pricing_info="₹850 (Single)\\nBoth Sessions: ₹1500"
  - event_details[1]: song="desi girl", pricing_info="₹850 (Single)\\nBoth Sessions: ₹1500"

EXPECTED TEXT FORMATS:
• Date: "Saturday, 24 January 2026" or "24th Jan" or "Jan 24"
• Time: "5:00 pm" with separate "Duration: 2 hours"
• When duration given: Calculate end_time = start_time + duration
  Example: "5:00 pm" + "2 hours" → start="05:00 PM", end="07:00 PM"
• Price: "₹850" per session, "₹1500" for combo

IGNORE: WhatsApp number, "Bangalore Workshops" text
""",

    "vins.dance.co": """
═══════════════════════════════════════════════════════════════
STUDIO: VINS DANCE CO
═══════════════════════════════════════════════════════════════

WHERE TO LOOK:
1. "Tickets" section → PRIMARY SOURCE for song names and prices
2. Header description text → Date and time for each song
3. Page title → Artist name (format: "{Artist} {month}")

WHAT TO EXTRACT:
• Each ticket WITH A UNIQUE SONG NAME = ONE event_details object
• Correlate ticket name with description for full details

⚠️ COMBO/BUNDLE HANDLING - CRITICAL:
• Tickets named "Both", "Combo", "Full Day", "All Sessions" are BUNDLES
• They are NOT separate workshops - do NOT create event_details for combos
• Only create event_details for tickets with actual song names
• Include combo price in EACH individual workshop's pricing_info

EXPECTED TEXT FORMATS:
• Title: "Aditya tripathi jan" → artist = "aditya tripathi"
• Description: "31st jan 1pm - Ishq hain" → day=31, month=1, start_time="01:00 PM", song="ishq hain"
• Description: "31st Jan 5pm - bananza" → day=31, month=1, start_time="05:00 PM", song="bananza"
• Ticket: "Bananza" with "₹850.00"

CORRELATION: Match ticket names to descriptions (case-insensitive)

PRICING: Extract base price only "₹850", EXCLUDE "+₹21.25 ticket service fee"

IGNORE: "Guests" section, "Time & Location", service fees, combo-only tickets
""",

    "dance.inn.bangalore": """
═══════════════════════════════════════════════════════════════
STUDIO: DANCE INN (RAZORPAY)
═══════════════════════════════════════════════════════════════

WHERE TO LOOK:
1. Payment Details section (RIGHT side) → PRIMARY SOURCE
2. Title "{Artist} at Dance-Inn" → Artist name
3. Left schedule → IGNORE (validation only)

**CRITICAL: EACH payment line item WITH A SONG NAME = ONE separate event_details object**
10 song line items = 10 event_details objects. NEVER merge them.

⚠️ COMBO/BUNDLE HANDLING:
• Line items like "Both Days", "Full Package", "Combo" are BUNDLES
• Do NOT create event_details for combo/bundle line items
• Only create event_details for line items with actual song names
• If combo pricing exists, include it in each individual workshop's pricing_info

LINE ITEM FORMAT: "{Song} by {Artist} on {Date} at {Time}" - ₹{Price}

PARSING EXAMPLES:
• "Mere rang Mai by Anvi Shetty on 23 Jan at 5pm"
  → song="mere rang mai", by="anvi shetty", day=23, month=1, start_time="05:00 PM"

• "Chaudhary by Anvi Shetty on 24th Jan at 1pm"
  → song="chaudhary", by="anvi shetty", day=24, month=1, start_time="01:00 PM"

• "Desi girl by Anvi Shetty on 25th Jan at 11am"
  → song="desi girl", by="anvi shetty", day=25, month=1, start_time="11:00 AM"

TIME FOR THIS STUDIO: "5pm"→"05:00 PM", "7pm"→"07:00 PM", "11am"→"11:00 AM", "1pm"→"01:00 PM", "3pm"→"03:00 PM"

PRICING: All items typically "₹950"

**EXCLUDE COMPLETELY:**
• "Service Fee ₹50.00" line - this is NOT a workshop
• Combo/bundle line items - include their price in individual workshops instead

IGNORE: Left schedule, "(Optional)" text, contact info, terms
""",

    "dance_n_addiction": """
═══════════════════════════════════════════════════════════════
STUDIO: DNA (YOACTIV)
═══════════════════════════════════════════════════════════════

WHERE TO LOOK:
1. "Session details" TABLE → PRIMARY SOURCE for song, date, time
2. "About Event" section → Pricing tiers
3. Poster → IGNORE
4. Header metadata (Time: 12:00 AM) → IGNORE, it's WRONG

SESSION TABLE FORMAT:
| Session Name | Date    | Time              |
|--------------|---------|-------------------|
| Pal Pal      | 07 Feb  | 05:00 PM-07:00 PM |
| Lapata       | 07 Feb  | 07:00 PM-09:00 PM |

Each row in the table = ONE event_details object (songs only, NOT combo rows)

⚠️ COMBO/BUNDLE HANDLING - CRITICAL:
• "Both Class", "All Sessions", "Combo" are PRICING OPTIONS, not workshops
• Do NOT create event_details for combo/bundle rows
• Only create event_details for rows with actual song names
• Include combo pricing in EACH individual workshop's pricing_info

ARTIST: From title "{Artist} _ {Date} Workshop" → extract before " _ "
Example: "Jordan _ 7th Feb Workshop" → by="jordan"

ABOUT EVENT PRICING FORMAT:
"Fee :- Single Class"
"899/- First 15"
"999/- After that"
"1200/- OTS"
"1599/- Both Class"

Convert to: "₹899 (First 15)\\n₹999 (Regular)\\n₹1200 (OTS)\\nBoth Classes: ₹1599"

CRITICAL: Apply SAME pricing_info (including combo price) to ALL individual song event_details.

IGNORE: Header "Time: 12:00 AM - 12:00 AM", "Warm regards, DNA", location
"""
}


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
    invalid_reason: Optional[str] = None  # Reason why is_valid=false (e.g., "past event", "not Bangalore", "not a dance event")


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
    ) -> tuple[Optional[Dict], Optional[str]]:
        """Process a single workshop link and return workshop data with optional rejection reason.

        Returns:
            tuple: (event_data, invalid_reason)
                - If valid: (event_data_dict, None)
                - If invalid: (None, "reason string")
        """
        screenshot_path = (
            f"screenshots/{studio.config.studio_id}_{link.split('/')[-1]}.png"
        )

        try:
            # Capture screenshot
            if not ScreenshotManager.capture_screenshot(link, screenshot_path):
                return None, "screenshot capture failed"

            # Analyze screenshot with selected AI model and studio-specific hints
            response = self.analyze_with_ai(screenshot_path, artists_data, studio_id=studio.config.studio_id)

            # Check response validity using the correct attribute
            if not response:
                return None, "AI analysis returned no response"

            if not response.is_valid:
                reason = response.invalid_reason if response.invalid_reason else "AI marked as invalid (no reason provided)"
                return None, reason

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

            return event_data, None  # Valid event, no rejection reason

        except Exception as e:
            logging.error(f"Error processing link {link}: {str(e)}")
            return None, f"error: {str(e)}"
        finally:
            # Cleanup screenshot
            if os.path.exists(screenshot_path):
                try:
                    os.remove(screenshot_path)
                except Exception as e:
                    logging.warning(f"Error cleaning up screenshot {screenshot_path}: {str(e)}")

    @retry(max_attempts=3, backoff_factor=2, exceptions=(Exception,))
    def analyze_with_ai(self, screenshot_path: str, artists_data: list = [], studio_id: str = None) -> Optional[EventSummary]:
        """Analyze workshop screenshot using the selected AI model.

        Includes automatic retry with exponential backoff for transient failures.

        Args:
            screenshot_path: Path to the screenshot file
            artists_data: List of artist data for context
            studio_id: Studio identifier for studio-specific extraction hints
        """
        if self.cfg.ai_model not in AI_MODEL_VERSIONS:
            raise ValueError(f"Unknown ai_model: {self.cfg.ai_model}. Valid options: {list(AI_MODEL_VERSIONS.keys())}")

        model_version = AI_MODEL_VERSIONS[self.cfg.ai_model]
        return self._analyze_with_ai(screenshot_path, artists_data=artists_data, model_version=model_version, studio_id=studio_id)

    def _generate_prompt(self, artists, current_date, studio_id=None):
        """Generates the comprehensive prompt for the AI model with studio-specific hints."""
        prompt = f"""You are an expert data extraction system for dance workshop events in Bangalore, India.
Analyze the screenshot and extract structured event information with precise formatting.

══════════════════════════════════════════════════════════════════════════════
CONTEXT
══════════════════════════════════════════════════════════════════════════════

Artists Database (for ID matching):
{artists}

Current Date: {current_date}

══════════════════════════════════════════════════════════════════════════════
TASK
══════════════════════════════════════════════════════════════════════════════

1. Determine if this is a valid Bangalore-based dance event (workshop/intensive/regulars)
2. If INVALID or PAST event → is_valid=false, event_details=[], invalid_reason="<brief reason>"
3. If VALID → is_valid=true, invalid_reason=null, Extract ALL workshops as SEPARATE event_details objects

══════════════════════════════════════════════════════════════════════════════
TIME EXTRACTION & NORMALIZATION
══════════════════════════════════════════════════════════════════════════════

OUTPUT FORMAT: Always "HH:MM AM/PM" with LEADING ZEROS

CONVERSION TABLE (memorize these):
┌─────────────────────┬─────────────────────────────────────┐
│ Input (any of)      │ Output                              │
├─────────────────────┼─────────────────────────────────────┤
│ 5pm, 5 pm, 5PM      │ start_time: "05:00 PM"              │
│ 5:00pm, 5:00 PM     │ start_time: "05:00 PM"              │
│ 17:00               │ start_time: "05:00 PM"              │
├─────────────────────┼─────────────────────────────────────┤
│ 11am, 11 am, 11AM   │ start_time: "11:00 AM"              │
│ 11:00am, 11:00 AM   │ start_time: "11:00 AM"              │
├─────────────────────┼─────────────────────────────────────┤
│ 1pm, 1 pm           │ start_time: "01:00 PM"              │
│ 13:00               │ start_time: "01:00 PM"              │
├─────────────────────┼─────────────────────────────────────┤
│ 3pm, 3 pm           │ start_time: "03:00 PM"              │
│ 7pm, 7 pm           │ start_time: "07:00 PM"              │
│ 9pm, 9 pm           │ start_time: "09:00 PM"              │
├─────────────────────┼─────────────────────────────────────┤
│ 5-7pm               │ start: "05:00 PM", end: "07:00 PM"  │
│ 5 to 7pm            │ start: "05:00 PM", end: "07:00 PM"  │
│ 5pm-7pm             │ start: "05:00 PM", end: "07:00 PM"  │
│ 5pm to 7pm          │ start: "05:00 PM", end: "07:00 PM"  │
│ 5:00 PM - 7:00 PM   │ start: "05:00 PM", end: "07:00 PM"  │
│ 05:00 PM-07:00 PM   │ start: "05:00 PM", end: "07:00 PM"  │
│ 17:00-19:00         │ start: "05:00 PM", end: "07:00 PM"  │
├─────────────────────┼─────────────────────────────────────┤
│ 5pm (2 hours)       │ start: "05:00 PM", end: "07:00 PM"  │
│ 5pm for 2hrs        │ start: "05:00 PM", end: "07:00 PM"  │
│ Duration: 2 hours   │ Add to start_time to get end_time   │
├─────────────────────┼─────────────────────────────────────┤
│ Only start, no end  │ start_time: "XX:XX XM", end: null   │
└─────────────────────┴─────────────────────────────────────┘

RULES:
• ALWAYS include leading zero: "05:00 PM" not "5:00 PM"
• ALWAYS include minutes: "05:00 PM" not "05 PM"
• ALWAYS uppercase AM/PM: "05:00 PM" not "05:00 pm"
• If end_time not available, use null

══════════════════════════════════════════════════════════════════════════════
DATE EXTRACTION & YEAR INFERENCE
══════════════════════════════════════════════════════════════════════════════

CONVERSION TABLE:
┌──────────────────────────────┬──────────────────────────┐
│ Input (any of)               │ Output                   │
├──────────────────────────────┼──────────────────────────┤
│ 24 Jan, 24 January           │ day: 24, month: 1        │
│ 24th Jan, 24th January       │ day: 24, month: 1        │
│ Jan 24, January 24           │ day: 24, month: 1        │
│ Jan 24th, January 24th       │ day: 24, month: 1        │
├──────────────────────────────┼──────────────────────────┤
│ 7 Feb, 7th Feb, Feb 7        │ day: 7, month: 2         │
│ 07 Feb                       │ day: 7, month: 2         │
├──────────────────────────────┼──────────────────────────┤
│ 24 Jan 2026                  │ day: 24, month: 1, year: 2026 │
│ January 24, 2026             │ day: 24, month: 1, year: 2026 │
│ Saturday, 24 January 2026    │ day: 24, month: 1, year: 2026 │
├──────────────────────────────┼──────────────────────────┤
│ 24/01, 24-01, 24.01          │ day: 24, month: 1        │
└──────────────────────────────┴──────────────────────────┘

ORDINAL NUMBERS:
1st→1, 2nd→2, 3rd→3, 4th→4, 5th→5, ..., 21st→21, 22nd→22, 23rd→23, 24th→24, ...31st→31

YEAR INFERENCE (Current date: {current_date}):
• If year is explicitly stated → use that year
• If date is TODAY or FUTURE in current year → use current year
• If date is PAST in current year → use NEXT year

══════════════════════════════════════════════════════════════════════════════
ARTIST NAME EXTRACTION
══════════════════════════════════════════════════════════════════════════════

OUTPUT: Always LOWERCASE

SINGLE ARTIST:
• "Anvi Shetty" → "anvi shetty"
• "JORDAN" → "jordan"
• "Aadil Khan" → "aadil khan"

MULTIPLE ARTISTS - Normalize ALL separators to " x ":
┌────────────────────────────────────┬────────────────────────────┐
│ Input                              │ Output (by field)          │
├────────────────────────────────────┼────────────────────────────┤
│ Aadil Khan X Krutika Solanki       │ "aadil khan x krutika solanki" │
│ Aadil Khan x Krutika Solanki       │ "aadil khan x krutika solanki" │
│ Aadil Khan & Krutika Solanki       │ "aadil khan x krutika solanki" │
│ Aadil Khan and Krutika Solanki     │ "aadil khan x krutika solanki" │
│ Aadil Khan feat Krutika Solanki    │ "aadil khan x krutika solanki" │
│ Aadil Khan featuring Krutika       │ "aadil khan x krutika solanki" │
│ Aadil Khan with Krutika Solanki    │ "aadil khan x krutika solanki" │
│ Aadil Khan ft Krutika Solanki      │ "aadil khan x krutika solanki" │
│ Aadil Khan ft. Krutika Solanki     │ "aadil khan x krutika solanki" │
└────────────────────────────────────┴────────────────────────────┘

ARTIST ID MATCHING:
• Compare 'by' field against artists database (case-insensitive)
• Match against BOTH artist_name AND artist_aliases (if provided)
• Example: If artist has name "aadil khan" and aliases ["aadil", "ak"], match any of these
• For multiple artists, check each name separately
• Add matched artist_id(s) to artist_id_list
• If no match found → empty array []

ARTISTS DATABASE FORMAT:
Each artist entry contains:
- artist_id: unique identifier (use this in artist_id_list)
- artist_name: primary name to match
- artist_aliases: list of alternative names/nicknames to also match against

══════════════════════════════════════════════════════════════════════════════
SONG NAME EXTRACTION
══════════════════════════════════════════════════════════════════════════════

OUTPUT: Always LOWERCASE

• "Pal Pal" → "pal pal"
• "PAL PAL" → "pal pal"
• "Ishq Hain" → "ishq hain"
• "MAYYA MAYYA" → "mayya mayya"
• "Mere Rang Mai" → "mere rang mai"
• "Desi Girl ❤️" → "desi girl" (remove emojis)

══════════════════════════════════════════════════════════════════════════════
PRICING EXTRACTION
══════════════════════════════════════════════════════════════════════════════

CURRENCY NORMALIZATION - Convert ALL to ₹ symbol:
• Rs.850, Rs 850, INR 850, 850/-, 850 rupees → ₹850

TIERED PRICING - Include ALL tiers with labels:
┌─────────────────────────────────┬──────────────────────┐
│ Input text                      │ Label to use         │
├─────────────────────────────────┼──────────────────────┤
│ First 15, Early bird, Phase 1   │ (First 15) or (Early Bird) │
│ After, Regular, Phase 2, Normal │ (Regular)            │
│ OTS, On the spot, Spot, Walk-in │ (OTS)                │
│ Both, Combo, Package, 2 classes │ "Both/Combo: ₹X"     │
└─────────────────────────────────┴──────────────────────┘

FORMAT with \\n separator:
"₹899 (First 15)\\n₹999 (Regular)\\n₹1200 (OTS)\\nBoth Classes: ₹1599"

EXCLUSIONS - DO NOT include:
• Service fees: "+₹50 service fee", "₹21.25 ticket service fee"
• Taxes: "GST", "+18% tax"
• Platform fees, convenience fees, booking fees

SIMPLE PRICING (no tiers):
• Just "₹850" or "₹950"

══════════════════════════════════════════════════════════════════════════════
MULTIPLE WORKSHOPS - CRITICAL RULE
══════════════════════════════════════════════════════════════════════════════

**Each DISTINCT song/routine = SEPARATE event_details object**

Examples:
• Page shows 2 songs by same artist → 2 event_details
• Page shows 3 songs on same date → 3 event_details
• Payment page with 10 line items → 10 event_details
• Same song on different dates → SEPARATE event_details

NEVER merge multiple songs into one event_details.

══════════════════════════════════════════════════════════════════════════════
COMBO WORKSHOPS - PRICING BUNDLES (NOT SEPARATE WORKSHOPS)
══════════════════════════════════════════════════════════════════════════════

**CRITICAL: Combo/Bundle options are PRICING STRATEGIES, not separate workshops**

When you see:
• "Workshop 1" (₹850)
• "Workshop 2" (₹850)
• "Combo: Workshop 1 + Workshop 2" (₹1500)
• "Both Sessions" (₹1500)
• "Full Day Package" (₹2000)

The combo is NOT a separate workshop. It's a discounted bundle of existing workshops.

CORRECT EXTRACTION (2 event_details, NOT 3):
┌─────────────────────────────────────────────────────────────────────────────┐
│ event_details[0]:                                                            │
│   song: "workshop 1 song name"                                               │
│   pricing_info: "₹850 (Single)\\nBoth Sessions: ₹1500"                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ event_details[1]:                                                            │
│   song: "workshop 2 song name"                                               │
│   pricing_info: "₹850 (Single)\\nBoth Sessions: ₹1500"                       │
└─────────────────────────────────────────────────────────────────────────────┘

WRONG EXTRACTION (creating 3 event_details):
❌ Creating a separate event_details for "Combo" or "Both Sessions"
❌ Creating event_details without a specific song name

COMBO IDENTIFICATION PATTERNS:
• "Both", "Combo", "Package", "Bundle", "Full Day"
• "Workshop 1 + Workshop 2", "Session 1 & Session 2"
• "All Sessions", "Complete Package"
• Price that equals sum of individual prices minus discount

RULE: If an option doesn't have its OWN unique song/routine, it's a combo.
Include combo pricing in EACH individual workshop's pricing_info field.

══════════════════════════════════════════════════════════════════════════════
MISSING INFORMATION - Graceful Handling
══════════════════════════════════════════════════════════════════════════════

• end_time not available → null (acceptable)
• year not stated → infer from current date
• song not clear → null (acceptable)
• pricing not found → null (acceptable)
• artist not in database → artist_id_list: [] (empty array)
• day or month missing → CANNOT proceed, is_valid: false

══════════════════════════════════════════════════════════════════════════════
OUTPUT SCHEMA
══════════════════════════════════════════════════════════════════════════════

Return ONLY this JSON structure:

{{
    "is_valid": <boolean>,
    "invalid_reason": <string | null>,
    "event_type": <"workshop" | "intensive" | "regulars" | null>,
    "event_details": [
        {{
            "time_details": [
                {{
                    "day": <integer 1-31>,
                    "month": <integer 1-12>,
                    "year": <integer 4-digit>,
                    "start_time": <string "HH:MM AM/PM" | null>,
                    "end_time": <string "HH:MM AM/PM" | null>
                }}
            ],
            "by": <string lowercase | null>,
            "song": <string lowercase | null>,
            "pricing_info": <string | null>,
            "artist_id_list": <array of strings>
        }}
    ]
}}

INVALID_REASON FIELD:
• If is_valid=true → invalid_reason should be null
• If is_valid=false → invalid_reason MUST contain a brief reason, such as:
  - "past event - {date} has already passed"
  - "not in Bangalore"
  - "not a dance workshop/event"
  - "page shows error/not found"
  - "insufficient information to extract event details"
  - "event is a regulars class, not workshop" (if filtering workshops only)

══════════════════════════════════════════════════════════════════════════════
SELF-VALIDATION CHECKLIST (verify before returning)
══════════════════════════════════════════════════════════════════════════════

□ is_valid is true ONLY for Bangalore dance events with future dates
□ event_type is exactly one of: "workshop", "intensive", "regulars"
□ EACH distinct song has its OWN event_details object
□ COMBO/BUNDLE options are NOT separate event_details (they're pricing only)
□ Combo pricing is INCLUDED in each individual workshop's pricing_info
□ ALL times are "HH:MM AM/PM" format WITH leading zeros (05:00 PM, not 5:00 PM)
□ ALL 'by' fields are lowercase
□ ALL 'song' fields are lowercase
□ Multiple artists use " x " separator (not &, and, feat, etc.)
□ pricing_info does NOT contain service fees or taxes
□ artist_id_list contains IDs only for matched artists

══════════════════════════════════════════════════════════════════════════════
IMPORTANT
══════════════════════════════════════════════════════════════════════════════

• Return ONLY raw JSON - no explanations, no markdown, no extra text
• Ensure all strings are properly escaped
• Use null for missing values, not empty strings
• Do not skip any workshops - extract ALL of them"""

        # Add studio-specific hints if available
        if studio_id and studio_id in STUDIO_EXTRACTION_HINTS:
            prompt = f"{prompt}\n\n{STUDIO_EXTRACTION_HINTS[studio_id]}"

        return prompt

    def _analyze_with_ai(
        self, screenshot_path: str, artists_data: list, model_version: str, studio_id: str = None
    ) -> Optional[EventSummary]:
        """Analyze workshop screenshot using GPT.

        Args:
            screenshot_path: Path to the screenshot file
            artists_data: List of artist data for context
            model_version: AI model version to use
            studio_id: Studio identifier for studio-specific extraction hints

        Returns:
            EventSummary object or None
        """
        try:
            # Read screenshot file
            with open(screenshot_path, "rb") as image_file:
                base64_image = base64.b64encode(image_file.read()).decode("utf-8")

            # Prepare GPT request with studio-specific prompt
            response = self.client.beta.chat.completions.parse(
                model=model_version,
                messages=[
                    {
                        "role": "system",
                        "content": self._generate_prompt(artists_data, date.today().strftime("%B %d, %Y"), studio_id),
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
            
            # Apply rate limiting delay based on model type
            for model_key, delay in AI_REQUEST_DELAY.items():
                if model_key in model_version.lower():
                    time.sleep(delay)
                    break
            
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
                is_valid=analyzed_data.get("is_valid", False),
                invalid_reason=analyzed_data.get("invalid_reason"),  # Capture reason for invalid events
                event_type=analyzed_data.get("event_type"),
                event_details=event_details_list
            )

        except Exception as e:
            logging.error(f"AI analysis error: {str(e)}")
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
            links = {x.lower() for x in studio.scrape_links()}
            workshop_updates = []
            ignored_links = {}  # Changed to dict: {link: reason}
            missing_artists = set()
            old_links = {}  # Changed to dict: {link: reason}

            # Pre-fetch all choreo_links to avoid database queries in loop
            all_choreo_links = {
                (cl["song"], tuple(sorted(cl.get("artist_id_list", [])))): cl["choreo_insta_link"]
                for cl in self.mongo_client["discovery"]["choreo_links"].find(
                    {"choreo_insta_link": {"$exists": True, "$ne": None}}
                )
                if cl.get("song")
            }

            with tqdm(
                total=len(links),
                desc=f"Processing {studio.config.studio_id}",
                position=self.position,
                leave=False,
            ) as pbar:
                for link in links:
                    # process_link now returns (event_data, invalid_reason)
                    event_data, invalid_reason = self.event_processor.process_link(
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
                                # Use pre-fetched choreo_links dictionary for efficiency
                                choreo_key = (event_detail["song"].lower(), tuple(sorted(event_detail["artist_id_list"])))
                                if choreo_key in all_choreo_links:
                                    inserted_data["choreo_insta_link"] = all_choreo_links[choreo_key]

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
                                reason = f"past event - date was {event_day}/{event_month}/{event_year}"
                                old_links[link] = reason
                                ignored_links[link] = reason
                            else:
                                workshop_updates.append(inserted_data)
                                # Check artist_id from event_detail
                                if not event_detail["artist_id_list"]:
                                    # Add tuple of (link, original 'by' field) for context
                                    missing_artists.add((link, event_detail.get("by"))) # Store link and 'by'
                    else:
                        # event_data is None, use the invalid_reason from AI
                        ignored_links[link] = invalid_reason or "unknown reason"

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
            return {}, {}, set(), studio.config.studio_id


def get_artists_data(cfg: config.Config) -> List[Dict]:
    """Get artist data from database."""
    client = DatabaseManager.get_mongo_client(cfg.env)
    return list(
        client["discovery"]["artists_v2"].find({}, {"artist_id": 1, "artist_name": 1, "artist_aliases": 1})
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
            "https://www.yoactiv.com/eventplugin.aspx?Apikey=ZL0C5CwgOJzo38yELwSW/g==&utm_source=ig&utm_medium=social&utm_content=link_in_bio",
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
            "https://manifest.twinmenot.com/",
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
            {}, {"artist_id": 1, "artist_name": 1, "artist_aliases": 1}
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
        ignored_links_all = {}
        # Wait for completion and handle errors
        for future in as_completed(futures):
            try:
                ignored_links, old_links, missing_artists, studio_id = future.result()
                ignored_links_all.update(ignored_links)

                if ignored_links:
                    print(f"\n{'='*60}")
                    print(f"Ignored Links for {studio_id} ({len(ignored_links)} links):")
                    print(f"{'='*60}")
                    for link, reason in ignored_links.items():
                        print(f"  • {link}")
                        print(f"    Reason: {reason}")

                if missing_artists:
                    print(f"\nMissing artists for {studio_id}:")
                    for link, artist_name in missing_artists:
                        print(f"  • {link} (artist: {artist_name})")

                if old_links:
                    print(f"\nOld/Past links for {studio_id} ({len(old_links)} links):")
                    for link, reason in old_links.items():
                        print(f"  • {link}")
                        print(f"    Reason: {reason}")
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
