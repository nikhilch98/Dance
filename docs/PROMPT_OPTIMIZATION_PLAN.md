# AI Prompt Optimization Plan for Workshop Data Extraction

## Executive Summary

This document outlines a comprehensive plan to optimize the AI prompt used in `scripts/populate_workshops.py` for extracting structured workshop data from dance studio websites. The optimization focuses on improving extraction accuracy while maintaining the existing data format.

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Studio-Specific Page Structures](#2-studio-specific-page-structures)
3. [Identified Issues with Current Prompt](#3-identified-issues-with-current-prompt)
4. [Proposed Solution Architecture](#4-proposed-solution-architecture)
5. [Studio-Specific Extraction Hints](#5-studio-specific-extraction-hints)
6. [Updated Prompt Template](#6-updated-prompt-template)
7. [Implementation Plan](#7-implementation-plan)
8. [Testing Strategy](#8-testing-strategy)

---

## 1. Current State Analysis

### 1.1 Current Prompt Location
- **File:** `scripts/populate_workshops.py`
- **Method:** `EventProcessor._generate_prompt()` (lines 153-223)
- **Model Config:** OpenAI (`gpt-5-mini`) or Gemini (`gemini-2.5-flash`)

### 1.2 Current Data Models (Unchanged)
```python
class TimeDetails(BaseModel):
    day: Optional[int] = None
    month: Optional[int] = None
    year: Optional[int] = None
    start_time: Optional[str] = None  # "HH:MM AM/PM"
    end_time: Optional[str] = None    # "HH:MM AM/PM"

class EventDetails(BaseModel):
    time_details: List[TimeDetails]
    by: Optional[str] = None           # Instructor name(s)
    song: Optional[str] = None         # Song/routine name
    pricing_info: Optional[str] = None # Pricing tiers separated by \n
    artist_id_list: Optional[List[str]] = []

class EventSummary(BaseModel):
    event_type: EventType  # "workshop", "intensive", "regulars"
    event_details: List[EventDetails]
    is_valid: bool
```

### 1.3 Current Prompt Strengths
- Clear JSON output schema with examples
- Handles multiple event types (workshop, intensive, regulars)
- Artist ID matching from provided artist list
- Bangalore-based event filtering
- Past event detection using current date

### 1.4 Current Prompt Weaknesses
- No visual hierarchy guidance for different page layouts
- Generic time extraction without format-specific examples
- Doesn't handle tiered pricing structures well
- Instructor name separator limited to ' X '
- Only one studio-specific mention (DNA) buried at the end
- No guidance on prioritizing structured text vs poster images

---

## 2. Studio-Specific Page Structures

### 2.1 Manifest (manifest.twinmenot.com)

**URL Pattern:** `https://manifest.twinmenot.com/workshops/{id}-{artist-name}`

**Page Layout:**
```
┌─────────────────────────────────────────────────────────────┐
│  [POSTER IMAGE]          │  "2 Workshops"                   │
│  - Artist name           │  "by {Artist Name}"              │
│  - Date overlay          │                                  │
│  - Time slots            │  "1. Select Session(s)"          │
│  - Pricing tiers         │  ┌─────────────────────────────┐ │
│  - WhatsApp number       │  │ [Song Name] - Checkbox      │ │
│                          │  │ Date: Saturday, 24 Jan 2026 │ │
│                          │  │ Time: 5:00 PM               │ │
│                          │  │ Duration: 2 hours           │ │
│                          │  │ Phase 1 (Active)    ₹850    │ │
│                          │  └─────────────────────────────┘ │
│                          │  ┌─────────────────────────────┐ │
│                          │  │ [Another Song] - Checkbox   │ │
│                          │  │ ...                         │ │
│                          │  └─────────────────────────────┘ │
│                          │  ┌─────────────────────────────┐ │
│                          │  │ COMBO (Both Workshops)      │ │
│                          │  │ Price: ₹1500                │ │
│                          │  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Data Extraction Priority:**
1. **Session cards (right side)** - DEFINITIVE source for song, date, time, price
2. **Header** - Artist name ("by {Artist}")
3. **Poster (left side)** - Validation/backup only

**Key Patterns:**
- Date format: "Saturday, 24 January 2026"
- Time format: "5:00 pm" with duration
- Multiple sessions = Multiple `event_details` objects
- COMBO pricing = Include in `pricing_info` of relevant sessions

---

### 2.2 Vins Dance Co (vinsdanceco.com)

**URL Pattern:** `https://www.vinsdanceco.com/events/{event-slug}`

**Page Layout:**
```
┌─────────────────────────────────────────────────────────────┐
│                    "{Artist Name} {month}"                   │
│                    ". | Vin's Dance Company"                 │
│                                                              │
│         "31st jan 1pm - Ishq hain"                          │
│         "31st Jan 5pm - bananza"                            │
│         "No refunds no transfers"                           │
│                                                              │
│                    [BOOK NOW]                                │
├─────────────────────────────────────────────────────────────┤
│  Time & Location                                             │
│  Vin's Dance Company, 4th Block, Koramangala, Bengaluru...  │
├─────────────────────────────────────────────────────────────┤
│  Guests                                                      │
│  [avatars] + 45 other guests                                │
├─────────────────────────────────────────────────────────────┤
│  Tickets                                                     │
│  ┌────────────────┬─────────────┬──────────┐                │
│  │ Ticket type    │ Price       │ Quantity │                │
│  │ Bananza        │ ₹850.00     │ [0 ▼]    │                │
│  │ More info ▼    │ +₹21.25 fee │          │                │
│  ├────────────────┼─────────────┼──────────┤                │
│  │ Ishq hain      │ ₹850.00     │ [0 ▼]    │                │
│  │ More info ▼    │ +₹21.25 fee │          │                │
│  └────────────────┴─────────────┴──────────┘                │
│                              Total: ₹0.00                    │
│                           [Checkout]                         │
└─────────────────────────────────────────────────────────────┘
```

**Data Extraction Priority:**
1. **Tickets section** - DEFINITIVE source for song names and prices
2. **Header description** - Date and time per song ("31st jan 1pm - Ishq hain")
3. **Title** - Artist name

**Key Patterns:**
- Date/Time inline: "31st jan 1pm - {Song}"
- Song names in Tickets match description
- Exclude service fees ("+₹21.25 fee")
- Each ticket type = separate `event_details` object

---

### 2.3 Dance Inn (pages.razorpay.com)

**URL Pattern:** `https://pages.razorpay.com/{event-slug}` or `https://rzp.io/rzp/{short-code}`

**Page Layout:**
```
┌─────────────────────────────────────────────────────────────┐
│  [Logo] Dance-Inn                                            │
│                                                              │
│  "{Artist Name} at Dance-Inn"                                │
│  ─────                                                       │
│                                                              │
│  Jan 23rd Fri                          Payment Details       │
│  • Mere rang me- 5pm to 7pm            ─────                 │
│  • mayya - 7pm to 9pm                  Email: [________]     │
│                                        Phone: [________]     │
│  Jan 24th sat                          Full Name: [______]   │
│  • Chaudhary : 1pm to 3pm                                    │
│  • Nadaan Parindey : 3pm to 5pm        Mere rang Mai by Anvi │
│  • Cham Cham : 5pm to 7pm              Shetty on 23 Jan at   │
│                                        5pm (Optional)        │
│  Show More                                    ₹950.00 [-0+]  │
│                                                              │
│  Contact Us:                           Mayya by Anvi Shetty  │
│  📧 contact@danceinn.studio            on 23 Jan at 7pm      │
│  📞 8296888670                         (Optional)            │
│                                               ₹950.00 [-0+]  │
│  Terms & Conditions:                                         │
│  [links...]                            Chaudhary by Anvi     │
│                                        Shetty on 24th Jan    │
│                                        at 1pm (Optional)     │
│                                               ₹950.00 [-0+]  │
│                                                              │
│                                        ... more items ...    │
│                                                              │
│                                        Service Fee           │
│                                               ₹50.00         │
└─────────────────────────────────────────────────────────────┘
```

**Data Extraction Priority:**
1. **Payment Details line items (right side)** - DEFINITIVE source
2. **Title** - Artist name ("{Artist} at Dance-Inn")
3. **Left schedule** - Validation only

**Key Patterns:**
- **CRITICAL:** Each payment line item = ONE workshop
- Line item format: `"{Song} by {Artist} on {Date} at {Time}"`
- All items typically same price (₹950.00)
- **EXCLUDE** "Service Fee" line from pricing
- Time format: "5pm", "7pm", "11am", "1pm", "3pm"
- Date format: "23 Jan", "24th Jan", "25th Jan"

**Example Extraction:**
```
Input: "Mere rang Mai by Anvi Shetty on 23 Jan at 5pm" - ₹950.00
Output:
{
  "time_details": [{"day": 23, "month": 1, "year": 2026, "start_time": "05:00 PM", "end_time": null}],
  "by": "anvi shetty",
  "song": "mere rang mai",
  "pricing_info": "₹950",
  "artist_id_list": ["anvi_shetty_id"]  // if matched
}
```

---

### 2.4 DNA - Dance N Addiction (yoactiv.com)

**URL Pattern:** `https://www.yoactiv.com/Event/{event-slug}/{id}/0`

**Page Layout:**
```
┌─────────────────────────────────────────────────────────────┐
│  "{Artist} _ {Date} Workshop"          [POSTER IMAGE]        │
│                                        - Artist name         │
│  DNA Dance An Addiction Studio         - Date                │
│  1st floor, 1070, 24th Main Rd...      - Time slots         │
│                                        - Song names          │
│  📅 Date: 07 Feb To 07 Feb                                   │
│  🕐 Time: 12:00 AM - 12:00 AM                               │
│  📍 Location: HSR LAYOUT                                     │
│  💰 Price: Price Start From Rs.899                          │
│                                                              │
│  [Direction] [Share] [Book Now]                              │
├─────────────────────────────────────────────────────────────┤
│  About    Terms & conditions                                 │
│  ─────                                                       │
│  About Event                                                 │
│                                                              │
│  {Artist} _ {Date} Workshop                                  │
│  Bangalore Dance Workshop with {Artist}                      │
│                                                              │
│  Date :- 7th Feb, Saturday                                   │
│  Time :- 5 to 7 pm .Song :- Pal Pal                         │
│  Time :- 7 to 9 pm .Song :- Lapata                          │
│                                                              │
│  Fee :- Single Class                                         │
│  899/- First 15                                              │
│  999/- After that                                            │
│  1200/- OTS .                                                │
│  1599/- Both Class                                           │
│                                                              │
│  Warm regards,                                               │
│  DNA                                                         │
├─────────────────────────────────────────────────────────────┤
│  Session details                                             │
│  ┌──────────────┬─────────┬───────────────────┐             │
│  │ Session Name │ Date    │ Time              │             │
│  │ Pal Pal      │ 07 Feb  │ 05:00 PM-07:00 PM │             │
│  ├──────────────┼─────────┼───────────────────┤             │
│  │ Lapata       │ 07 Feb  │ 07:00 PM-09:00 PM │             │
│  └──────────────┴─────────┴───────────────────┘             │
├─────────────────────────────────────────────────────────────┤
│  Location                                                    │
│  📍 HSR LAYOUT                                               │
│  DNA Dance An Addiction Studio...                           │
└─────────────────────────────────────────────────────────────┘
```

**Data Extraction Priority:**
1. **Session details table** - DEFINITIVE for song, date, time
2. **About Event section** - Pricing tiers, additional context
3. **Poster** - Validation only

**Key Patterns:**
- Session table columns: Session Name | Date | Time
- Time format in table: "05:00 PM - 07:00 PM"
- About section format: "Time :- {time} .Song :- {song}"
- Pricing tiers: "First 15", "After that", "OTS", "Both Class"
- Each session = separate `event_details` with SHARED pricing_info

---

## 3. Identified Issues with Current Prompt

### 3.1 Visual Hierarchy Issues
| Issue | Impact | Solution |
|-------|--------|----------|
| No guidance on where to look first | AI may extract from poster instead of structured data | Add priority order for each studio |
| Poster vs structured text conflicts | Inconsistent data when sources differ | Specify structured text takes precedence |

### 3.2 Format Parsing Issues
| Issue | Examples | Solution |
|-------|----------|----------|
| Time format variations | "5pm", "5:00 PM", "5 to 7 pm", "05:00 PM - 07:00 PM" | Add explicit format examples |
| Date format variations | "23 Jan", "24th Jan", "7th Feb, Saturday", "Saturday, 24 January 2026" | Add parsing examples |
| Instructor separators | " X ", " x ", " & ", " and ", " featuring " | Expand separator list |

### 3.3 Pricing Structure Issues
| Issue | Examples | Solution |
|-------|----------|----------|
| Tiered pricing | "899/- First 15, 999/- After that, 1200/- OTS" | Add tiered extraction guidance |
| Service fees included | "+₹21.25 fee", "Service Fee ₹50.00" | Explicitly exclude fees |
| Combo pricing | "Both Class: ₹1599", "COMBO: ₹1500" | Include in relevant sessions |

### 3.4 Multi-Workshop Extraction Issues
| Issue | Impact | Solution |
|-------|--------|----------|
| Single event_details for multi-song pages | Missing workshops | Each song = separate event_details |
| Shared vs separate pricing | Incorrect pricing per workshop | Studio-specific rules |

---

## 4. Proposed Solution Architecture

### 4.1 Hybrid Approach: Generic Base + Studio-Specific Hints

```
┌─────────────────────────────────────────────────────────────┐
│                    GENERIC BASE PROMPT                       │
│  - Output schema definition                                  │
│  - General extraction rules                                  │
│  - Format specifications                                     │
│  - Validation requirements                                   │
├─────────────────────────────────────────────────────────────┤
│                  STUDIO-SPECIFIC HINTS                       │
│  - Visual hierarchy for this studio                         │
│  - Key patterns to look for                                 │
│  - Format examples from this studio                         │
│  - Common edge cases                                        │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Code Architecture Changes

```python
# New: Studio extraction hints dictionary
STUDIO_EXTRACTION_HINTS = {
    "manifestbytmn": "...",
    "vins.dance.co": "...",
    "dance.inn.bangalore": "...",
    "dance_n_addiction": "..."
}

# Modified: _generate_prompt signature
def _generate_prompt(self, artists, current_date, studio_id=None):
    base_prompt = self._get_base_prompt(artists, current_date)

    if studio_id and studio_id in STUDIO_EXTRACTION_HINTS:
        studio_hints = STUDIO_EXTRACTION_HINTS[studio_id]
        return f"{base_prompt}\n\n{studio_hints}"

    return base_prompt

# Modified: Call chain to pass studio_id
def analyze_with_ai(self, screenshot_path, artists_data, studio_id=None):
    ...
    return self._analyze_with_ai(screenshot_path, artists_data, model_version, studio_id)

def _analyze_with_ai(self, screenshot_path, artists_data, model_version, studio_id=None):
    ...
    prompt = self._generate_prompt(artists_data, current_date, studio_id)
    ...
```

---

## 5. Studio-Specific Extraction Hints

### 5.1 Manifest (manifestbytmn)

```python
MANIFEST_HINTS = """
═══════════════════════════════════════════════════════════════
STUDIO-SPECIFIC EXTRACTION HINTS: MANIFEST BY TMN
═══════════════════════════════════════════════════════════════

VISUAL HIERARCHY (extract in this order):
1. Session selection cards (right side) - PRIMARY SOURCE
2. Header text "by {Artist Name}" - Artist name
3. Poster image (left side) - VALIDATION ONLY, do not prioritize

KEY PATTERNS:
- Each session card contains: Song name, Date, Time, Duration, Price
- "Phase 1 (Active)" or "Phase 2" indicates availability status
- COMBO option is a separate card for booking multiple workshops together

DATE/TIME FORMAT:
- Date: "Saturday, 24 January 2026" → day=24, month=1, year=2026
- Time: "5:00 pm" with "Duration: 2 hours" → start_time="05:00 PM", end_time="07:00 PM"
- Calculate end_time from start_time + duration if end_time not explicit

PRICING:
- Individual session price shown on each card (e.g., ₹850)
- COMBO price is for multiple sessions together
- Include individual price in each event_details
- Mention combo option in pricing_info: "₹850 per session\nCombo (both): ₹1500"

MULTIPLE WORKSHOPS:
- Each session card = ONE event_details object
- Same artist, same date, different songs = SEPARATE event_details
- Share pricing_info format across related sessions

IGNORE:
- WhatsApp registration number at bottom
- "Bangalore Workshops" text (location confirmation only)
"""
```

### 5.2 Vins Dance Co (vins.dance.co)

```python
VINS_HINTS = """
═══════════════════════════════════════════════════════════════
STUDIO-SPECIFIC EXTRACTION HINTS: VINS DANCE CO
═══════════════════════════════════════════════════════════════

VISUAL HIERARCHY (extract in this order):
1. "Tickets" section - PRIMARY SOURCE for song names and prices
2. Header description lines - Date and time for each song
3. Page title - Artist name

KEY PATTERNS:
- Title format: "{Artist name} {month}" (e.g., "Aditya tripathi jan")
- Description lines: "{Date} {time} - {Song}" (e.g., "31st jan 1pm - Ishq hain")
- Tickets section lists each song as a "Ticket type" with price

DATE/TIME FORMAT:
- Description: "31st jan 1pm" → day=31, month=1, start_time="01:00 PM"
- Only start_time is provided; end_time may be null or inferred from next session

PRICING:
- Each ticket shows base price (e.g., ₹850.00)
- EXCLUDE service fees (e.g., "+₹21.25 ticket service fee")
- pricing_info should only contain the base price: "₹850"

MULTIPLE WORKSHOPS:
- Each ticket type = ONE event_details object
- Match ticket names to description lines for complete data
- Example: Ticket "Bananza" matches description "31st Jan 5pm - bananza"

CORRELATION REQUIRED:
- Song name in Tickets must be matched with date/time from description
- Case may differ (Bananza vs bananza) - match case-insensitively

IGNORE:
- "Guests" section
- "Time & Location" section (only confirms Bangalore)
- Checkout/Total area
"""
```

### 5.3 Dance Inn (dance.inn.bangalore)

```python
DANCEINN_HINTS = """
═══════════════════════════════════════════════════════════════
STUDIO-SPECIFIC EXTRACTION HINTS: DANCE INN (RAZORPAY)
═══════════════════════════════════════════════════════════════

VISUAL HIERARCHY (extract in this order):
1. Payment Details line items (right side) - PRIMARY SOURCE
2. Title "{Artist} at Dance-Inn" - Artist name
3. Left side schedule - VALIDATION ONLY

CRITICAL PATTERN:
Each payment line item IS a separate workshop. Format:
"{Song} by {Artist} on {Date} at {Time}" - ₹{Price}

Examples:
- "Mere rang Mai by Anvi Shetty on 23 Jan at 5pm" →
  song="mere rang mai", by="anvi shetty", day=23, month=1, start_time="05:00 PM"
- "Chaudhary by Anvi Shetty on 24th Jan at 1pm" →
  song="chaudhary", by="anvi shetty", day=24, month=1, start_time="01:00 PM"

DATE/TIME FORMAT:
- Date: "23 Jan", "24th Jan", "25th Jan" → Extract day and month
- Time: "5pm", "7pm", "11am", "1pm", "3pm" → Normalize to "HH:MM AM/PM"
  - "5pm" → "05:00 PM"
  - "11am" → "11:00 AM"
  - "1pm" → "01:00 PM"
- end_time is typically null (not provided)

PRICING:
- All workshops usually have the same price (e.g., ₹950.00)
- pricing_info: "₹950"
- **CRITICAL: EXCLUDE "Service Fee" line** (e.g., ₹50.00)

MULTIPLE WORKSHOPS:
- **EACH line item in Payment Details = ONE event_details object**
- A page with 10 line items = 10 separate event_details objects
- Same artist across all, but different songs and times

YEAR INFERENCE:
- Year not provided in dates
- If month/day is in the future relative to current date, use current year
- If month/day has passed, use next year

IGNORE:
- Left side grouped schedule (use only for validation)
- Contact information
- Terms & Conditions links
- "(Optional)" text after each line item
"""
```

### 5.4 DNA - Dance N Addiction (dance_n_addiction)

```python
DNA_HINTS = """
═══════════════════════════════════════════════════════════════
STUDIO-SPECIFIC EXTRACTION HINTS: DNA (YOACTIV)
═══════════════════════════════════════════════════════════════

VISUAL HIERARCHY (extract in this order):
1. "Session details" table - PRIMARY SOURCE for song, date, time
2. "About Event" section - Pricing tiers and additional context
3. Poster image - VALIDATION ONLY

SESSION DETAILS TABLE:
┌──────────────┬─────────┬───────────────────┐
│ Session Name │ Date    │ Time              │
│ Pal Pal      │ 07 Feb  │ 05:00 PM-07:00 PM │
│ Lapata       │ 07 Feb  │ 07:00 PM-09:00 PM │
└──────────────┴─────────┴───────────────────┘

- Session Name = song
- Date = "07 Feb" → day=7, month=2
- Time = "05:00 PM-07:00 PM" → start_time="05:00 PM", end_time="07:00 PM"

ABOUT EVENT SECTION FORMAT:
"Date :- 7th Feb, Saturday"
"Time :- 5 to 7 pm .Song :- Pal Pal"
"Time :- 7 to 9 pm .Song :- Lapata"
"Fee :- Single Class"
"899/- First 15"
"999/- After that"
"1200/- OTS ."
"1599/- Both Class"

PRICING (TIERED):
- Extract ALL pricing tiers into pricing_info
- Format: "Single Class:\n₹899 (First 15)\n₹999 (After)\n₹1200 (OTS)\nBoth Classes: ₹1599"
- "OTS" = On The Spot
- "First 15" = Early bird for first 15 registrations
- Apply SAME pricing_info to ALL event_details from same event

ARTIST NAME:
- Extract from title: "{Artist} _ {Date} Workshop" → artist is before " _ "
- Example: "Jordan _ 7th Feb Workshop" → by="jordan"

MULTIPLE WORKSHOPS:
- Each row in Session details table = ONE event_details object
- All sessions share the same pricing_info (it's event-level, not session-level)

DATE/TIME FORMAT:
- Table: "07 Feb" → day=7, month=2
- Table: "05:00 PM-07:00 PM" → Already in correct format
- About section: "5 to 7 pm" → start_time="05:00 PM", end_time="07:00 PM"

IGNORE:
- Header metadata (Date: 07 Feb To 07 Feb, Time: 12:00 AM - 12:00 AM) - often incorrect
- "Warm regards, DNA" signature
- Location details (confirms Bangalore only)
"""
```

---

## 6. Updated Prompt Template

### 6.1 Base Prompt (Generic)

```python
def _get_base_prompt(self, artists, current_date):
    return f"""You are an expert data extraction system for dance workshop events.
Analyze the provided screenshot to extract structured event information.

══════════════════════════════════════════════════════════════════
CONTEXT
══════════════════════════════════════════════════════════════════

Artists Database (for matching instructor names to IDs):
{artists}

Current Date (for determining if events are past/future):
{current_date}

══════════════════════════════════════════════════════════════════
TASK
══════════════════════════════════════════════════════════════════

1. DETERMINE if this is a valid Bangalore-based dance event (workshop, intensive, or regulars)
2. If NOT valid OR event date is in the past → set is_valid=false, return empty event_details
3. If VALID → Extract all event details into structured format

══════════════════════════════════════════════════════════════════
EXTRACTION RULES
══════════════════════════════════════════════════════════════════

VISUAL HIERARCHY (when sources conflict):
1. Structured tables/lists → HIGHEST PRIORITY
2. Labeled sections (About Event, Tickets, Session Details) → HIGH PRIORITY
3. Inline text descriptions → MEDIUM PRIORITY
4. Poster/Banner images → LOWEST PRIORITY (use for validation only)

MULTIPLE WORKSHOPS:
- If a page contains multiple songs/routines with separate times → Create SEPARATE event_details for EACH
- Same artist teaching 3 songs = 3 event_details objects
- Combo/package pricing can be mentioned in each session's pricing_info

TIME FORMAT NORMALIZATION:
Input variations → Output format "HH:MM AM/PM"
- "5pm", "5 pm", "5PM" → "05:00 PM"
- "11am" → "11:00 AM"
- "1pm" → "01:00 PM"
- "5:00 pm" → "05:00 PM"
- "17:00" → "05:00 PM"
- "5 to 7 pm" → start_time="05:00 PM", end_time="07:00 PM"
- "05:00 PM-07:00 PM" → start_time="05:00 PM", end_time="07:00 PM"

DATE EXTRACTION:
- "24 January 2026" → day=24, month=1, year=2026
- "24th Jan" → day=24, month=1, year=(infer from current date)
- "Jan 23rd" → day=23, month=1, year=(infer)
- "7th Feb, Saturday" → day=7, month=2, year=(infer)
- Year inference: If date is future relative to {current_date}, use current year; otherwise next year

INSTRUCTOR NAME (by field):
- Extract instructor/artist name(s)
- Multiple instructors may be separated by: ' X ', ' x ', ' & ', ' and ', ' featuring ', ' feat ', ' with '
- Normalize to: "artist1 x artist2" format (lowercase, ' x ' separator)
- Store as lowercase in 'by' field

ARTIST ID MATCHING:
- Compare extracted instructor name against artists database
- If match found, add artist_id to artist_id_list
- Multiple instructors = multiple IDs in the list
- No match = empty array []

PRICING EXTRACTION:
- Extract base prices only
- **EXCLUDE**: Service fees, GST, taxes, booking fees, convenience fees
- Format tiers on separate lines with \\n:
  "₹899 (First 15)\\n₹999 (After)\\n₹1200 (OTS)"
- Include combo pricing if relevant:
  "₹850 per session\\nBoth sessions: ₹1500"

══════════════════════════════════════════════════════════════════
OUTPUT SCHEMA
══════════════════════════════════════════════════════════════════

Return ONLY a valid JSON object with this exact structure:

{{
    "is_valid": <boolean>,
    "event_type": <"workshop" | "intensive" | "regulars" | null>,
    "event_details": [
        {{
            "time_details": [
                {{
                    "day": <int | null>,
                    "month": <int | null>,
                    "year": <int | null>,
                    "start_time": <string "HH:MM AM/PM" | null>,
                    "end_time": <string "HH:MM AM/PM" | null>
                }}
            ],
            "by": <string (lowercase) | null>,
            "song": <string (lowercase) | null>,
            "pricing_info": <string | null>,
            "artist_id_list": <array of strings>
        }}
    ]
}}

══════════════════════════════════════════════════════════════════
VALIDATION CHECKLIST
══════════════════════════════════════════════════════════════════

Before returning, verify:
□ is_valid is true only for Bangalore-based dance events with future dates
□ event_type is one of: "workshop", "intensive", "regulars"
□ Each distinct song/routine has its own event_details object
□ Times are in "HH:MM AM/PM" format with leading zeros
□ 'by' and 'song' fields are lowercase
□ pricing_info excludes service fees/taxes
□ artist_id_list contains IDs only for matched artists

══════════════════════════════════════════════════════════════════
IMPORTANT
══════════════════════════════════════════════════════════════════

- Return ONLY the raw JSON object
- No explanations, no markdown formatting, no extra text
- Ensure all string values are properly escaped
- Use null for missing/unknown values, not empty strings
"""
```

### 6.2 Complete _generate_prompt Method

```python
# Add this constant at the top of the file (after imports)
STUDIO_EXTRACTION_HINTS = {
    "manifestbytmn": """
═══════════════════════════════════════════════════════════════
STUDIO-SPECIFIC HINTS: MANIFEST BY TMN
═══════════════════════════════════════════════════════════════
PRIORITY: Session selection cards (right side) > Header > Poster
- Each session card = ONE event_details (song, date, time, price)
- Date format: "Saturday, 24 January 2026"
- Time: "5:00 pm" + Duration → calculate end_time
- COMBO is separate card; mention in pricing_info
- Ignore WhatsApp number
""",

    "vins.dance.co": """
═══════════════════════════════════════════════════════════════
STUDIO-SPECIFIC HINTS: VINS DANCE CO
═══════════════════════════════════════════════════════════════
PRIORITY: Tickets section > Header description > Title
- Description format: "{Date} {time} - {Song}" (e.g., "31st jan 1pm - Ishq hain")
- Each ticket type = ONE event_details
- Match ticket names to description for date/time
- EXCLUDE service fees ("+₹21.25 fee")
- Ignore Guests section
""",

    "dance.inn.bangalore": """
═══════════════════════════════════════════════════════════════
STUDIO-SPECIFIC HINTS: DANCE INN (RAZORPAY)
═══════════════════════════════════════════════════════════════
PRIORITY: Payment Details line items (right side) - THIS IS THE PRIMARY SOURCE
- **CRITICAL**: Each line item = ONE separate workshop
- Format: "{Song} by {Artist} on {Date} at {Time}" - ₹Price
- Example: "Mere rang Mai by Anvi Shetty on 23 Jan at 5pm" - ₹950.00
  → song="mere rang mai", by="anvi shetty", day=23, month=1, start_time="05:00 PM", pricing_info="₹950"
- Time: "5pm"→"05:00 PM", "11am"→"11:00 AM", "1pm"→"01:00 PM"
- **EXCLUDE "Service Fee" line entirely**
- 10 line items = 10 event_details objects
- Left side schedule is for validation only
""",

    "dance_n_addiction": """
═══════════════════════════════════════════════════════════════
STUDIO-SPECIFIC HINTS: DNA (YOACTIV)
═══════════════════════════════════════════════════════════════
PRIORITY: Session details table > About Event section > Poster
- Session table: Session Name | Date | Time (e.g., "Pal Pal | 07 Feb | 05:00 PM-07:00 PM")
- Each table row = ONE event_details
- Artist from title: "{Artist} _ {Date} Workshop" → extract before " _ "
- Pricing is SHARED across all sessions from About Event:
  "Fee :- Single Class\\n899/- First 15\\n999/- After that\\n1200/- OTS\\n1599/- Both Class"
- Format pricing_info: "₹899 (First 15)\\n₹999 (After)\\n₹1200 (OTS)\\nBoth: ₹1599"
- Ignore header metadata (often shows 12:00 AM incorrectly)
"""
}


def _generate_prompt(self, artists, current_date, studio_id=None):
    """Generates the prompt for the AI model with optional studio-specific hints."""

    base_prompt = f"""You are an expert data extraction system for dance workshop events.
Analyze the provided screenshot to extract structured event information.

══════════════════════════════════════════════════════════════════
CONTEXT
══════════════════════════════════════════════════════════════════

Artists Database (for matching instructor names to IDs):
{artists}

Current Date (for determining if events are past/future):
{current_date}

══════════════════════════════════════════════════════════════════
TASK
══════════════════════════════════════════════════════════════════

1. DETERMINE if this is a valid Bangalore-based dance event (workshop, intensive, or regulars)
2. If NOT valid OR event date is in the past → set is_valid=false, return empty event_details
3. If VALID → Extract all event details into structured format

══════════════════════════════════════════════════════════════════
EXTRACTION RULES
══════════════════════════════════════════════════════════════════

VISUAL HIERARCHY (when sources conflict):
1. Structured tables/lists → HIGHEST PRIORITY
2. Labeled sections (About Event, Tickets, Session Details) → HIGH PRIORITY
3. Inline text descriptions → MEDIUM PRIORITY
4. Poster/Banner images → LOWEST PRIORITY (validation only)

MULTIPLE WORKSHOPS:
- Each distinct song/routine with separate time = SEPARATE event_details
- Same artist with 3 songs = 3 event_details objects
- Combo pricing mentioned in each relevant session's pricing_info

TIME FORMAT - Normalize to "HH:MM AM/PM":
- "5pm" → "05:00 PM"
- "11am" → "11:00 AM"
- "1pm" → "01:00 PM"
- "5:00 pm" → "05:00 PM"
- "5 to 7 pm" → start="05:00 PM", end="07:00 PM"
- "05:00 PM-07:00 PM" → start="05:00 PM", end="07:00 PM"

DATE EXTRACTION:
- "24 January 2026" → day=24, month=1, year=2026
- "24th Jan" → day=24, month=1, year=infer
- "7th Feb, Saturday" → day=7, month=2
- Year: future date → current year; past date → next year

INSTRUCTOR NAME ('by' field):
- Separators: ' X ', ' x ', ' & ', ' and ', ' featuring '
- Output: lowercase, "artist1 x artist2"

PRICING:
- **EXCLUDE**: Service fees, GST, taxes, booking fees
- Tiers separated by \\n: "₹899 (First 15)\\n₹999 (After)\\n₹1200 (OTS)"

══════════════════════════════════════════════════════════════════
OUTPUT SCHEMA
══════════════════════════════════════════════════════════════════

Return ONLY valid JSON:

{{
    "is_valid": <boolean>,
    "event_type": <"workshop" | "intensive" | "regulars" | null>,
    "event_details": [
        {{
            "time_details": [
                {{
                    "day": <int | null>,
                    "month": <int | null>,
                    "year": <int | null>,
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

Return ONLY raw JSON. No explanations, no markdown."""

    # Add studio-specific hints if available
    if studio_id and studio_id in STUDIO_EXTRACTION_HINTS:
        base_prompt = f"{base_prompt}\n\n{STUDIO_EXTRACTION_HINTS[studio_id]}"

    return base_prompt
```

---

## 7. Implementation Plan

### 7.1 Files to Modify

| File | Changes |
|------|---------|
| `scripts/populate_workshops.py` | Add STUDIO_EXTRACTION_HINTS, modify _generate_prompt, update call chain |

### 7.2 Step-by-Step Implementation

#### Step 1: Add Studio Hints Constant
```python
# Add after line 43 (after AI_REQUEST_DELAY)
STUDIO_EXTRACTION_HINTS = { ... }  # As defined in Section 5
```

#### Step 2: Update _generate_prompt Method
```python
# Replace lines 153-223 with new implementation
def _generate_prompt(self, artists, current_date, studio_id=None):
    # New implementation as shown in Section 6.2
```

#### Step 3: Update analyze_with_ai Method
```python
# Modify line 142 to accept studio_id
@retry(max_attempts=3, backoff_factor=2, exceptions=(Exception,))
def analyze_with_ai(self, screenshot_path: str, artists_data: list = [], studio_id: str = None) -> Optional[EventSummary]:
    ...
    return self._analyze_with_ai(screenshot_path, artists_data=artists_data, model_version=model_version, studio_id=studio_id)
```

#### Step 4: Update _analyze_with_ai Method
```python
# Modify line 225 to accept and use studio_id
def _analyze_with_ai(
    self, screenshot_path: str, artists_data: list, model_version: str, studio_id: str = None
) -> Optional[EventSummary]:
    ...
    # Line 248: Pass studio_id to _generate_prompt
    "content": self._generate_prompt(artists_data, date.today().strftime("%B %d, %Y"), studio_id),
```

#### Step 5: Update process_link Method
```python
# Modify line 103 to pass studio.config.studio_id
response = self.analyze_with_ai(screenshot_path, artists_data, studio_id=studio.config.studio_id)
```

### 7.3 Backward Compatibility

All changes are **additive and backward compatible**:
- `studio_id` parameter is optional with default `None`
- If no studio_id provided, base prompt is used (current behavior)
- Data models remain unchanged
- Output format remains unchanged

---

## 8. Testing Strategy

### 8.1 Test Cases per Studio

| Studio | Test URL | Expected Extractions |
|--------|----------|---------------------|
| Manifest | `/workshops/222-junaid-sharif` | 2 workshops (Hai Rama, Mayya Mayya), same date, different times |
| Vins | `/events/aditya-tripathi-jan-1` | 2 workshops (Ishq hain, Bananza), same date, different times |
| Dance Inn | Razorpay page | 10+ workshops, each line item separate, same artist |
| DNA | `/Event/jordan-_-7th-feb-workshop/` | 2 workshops (Pal Pal, Lapata), tiered pricing shared |

### 8.2 Validation Criteria

For each test:
1. ✓ Correct number of event_details objects
2. ✓ All song names extracted (lowercase)
3. ✓ All dates correctly parsed (day, month, year)
4. ✓ All times in "HH:MM AM/PM" format
5. ✓ Artist names lowercase
6. ✓ Pricing excludes service fees
7. ✓ artist_id_list populated if match exists

### 8.3 Regression Testing

Run full pipeline for all studios and compare:
- Total workshops extracted (should increase or stay same)
- Data quality (fewer null fields)
- No false positives (invalid events marked valid)

---

## Appendix A: Sample Expected Outputs

### A.1 Dance Inn (10 workshops from screenshot)

```json
{
  "is_valid": true,
  "event_type": "workshop",
  "event_details": [
    {
      "time_details": [{"day": 23, "month": 1, "year": 2026, "start_time": "05:00 PM", "end_time": null}],
      "by": "anvi shetty",
      "song": "mere rang mai",
      "pricing_info": "₹950",
      "artist_id_list": []
    },
    {
      "time_details": [{"day": 23, "month": 1, "year": 2026, "start_time": "07:00 PM", "end_time": null}],
      "by": "anvi shetty",
      "song": "mayya",
      "pricing_info": "₹950",
      "artist_id_list": []
    },
    {
      "time_details": [{"day": 24, "month": 1, "year": 2026, "start_time": "01:00 PM", "end_time": null}],
      "by": "anvi shetty",
      "song": "chaudhary",
      "pricing_info": "₹950",
      "artist_id_list": []
    }
    // ... 7 more event_details for remaining workshops
  ]
}
```

### A.2 DNA (2 workshops with shared pricing)

```json
{
  "is_valid": true,
  "event_type": "workshop",
  "event_details": [
    {
      "time_details": [{"day": 7, "month": 2, "year": 2026, "start_time": "05:00 PM", "end_time": "07:00 PM"}],
      "by": "jordan",
      "song": "pal pal",
      "pricing_info": "₹899 (First 15)\n₹999 (After)\n₹1200 (OTS)\nBoth: ₹1599",
      "artist_id_list": []
    },
    {
      "time_details": [{"day": 7, "month": 2, "year": 2026, "start_time": "07:00 PM", "end_time": "09:00 PM"}],
      "by": "jordan",
      "song": "lapata",
      "pricing_info": "₹899 (First 15)\n₹999 (After)\n₹1200 (OTS)\nBoth: ₹1599",
      "artist_id_list": []
    }
  ]
}
```

---

## Appendix B: Quick Reference - Key Changes Summary

| Component | Current | Proposed |
|-----------|---------|----------|
| Prompt length | ~3500 chars | ~2500 chars base + ~500 chars hints |
| Studio-specific logic | 1 mention (DNA) | Full hints for all 4 studios |
| Time format examples | None | 6 explicit conversions |
| Pricing guidance | Basic | Tiered + exclusion rules |
| Multi-workshop handling | Implicit | Explicit per-studio rules |
| Visual hierarchy | None | 4-level priority system |

---

*Document Version: 1.0*
*Created: January 2026*
*Author: AI Prompt Optimization Analysis*
