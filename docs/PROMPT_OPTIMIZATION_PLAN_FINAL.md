# AI Prompt Optimization Plan - Final Version (AI-Only)

## Approach

**Single Layer: Comprehensive AI Prompt**
- No post-processing code
- AI handles all normalization, matching, and validation
- Prompt includes exhaustive examples and strict rules

---

## Table of Contents

1. [Studio-Specific Hints](#1-studio-specific-hints)
2. [Complete Prompt Template](#2-complete-prompt-template)
3. [Implementation](#3-implementation)

---

## 1. Studio-Specific Hints

### 1.1 Manifest (manifestbytmn)

```python
"manifestbytmn": """
═══════════════════════════════════════════════════════════════
STUDIO: MANIFEST BY TMN
═══════════════════════════════════════════════════════════════

WHERE TO LOOK:
1. Session selection cards (RIGHT side) → PRIMARY SOURCE
2. Header "by {Artist Name}" → Artist name
3. Poster (LEFT) → IGNORE, use for validation only

WHAT TO EXTRACT:
• Each session card = ONE event_details object
• Card contains: Song name (title), Date, Time, Duration, Price
• "Phase 1 (Active)" = session is available

EXPECTED TEXT FORMATS:
• Date: "Saturday, 24 January 2026" or "24th Jan" or "Jan 24"
• Time: "5:00 pm" with separate "Duration: 2 hours"
• When duration given: Calculate end_time = start_time + duration
  Example: "5:00 pm" + "2 hours" → start="05:00 PM", end="07:00 PM"
• Price: "₹850" per session, "₹1500" for combo

PRICING FORMAT:
Include both individual and combo pricing:
"₹850 per session\\nBoth sessions: ₹1500"

IGNORE:
• WhatsApp number at bottom
• "Bangalore Workshops" text
"""
```

### 1.2 Vins Dance Co (vins.dance.co)

```python
"vins.dance.co": """
═══════════════════════════════════════════════════════════════
STUDIO: VINS DANCE CO
═══════════════════════════════════════════════════════════════

WHERE TO LOOK:
1. "Tickets" section → PRIMARY SOURCE for song names and prices
2. Header description text → Date and time for each song
3. Page title → Artist name (format: "{Artist} {month}")

WHAT TO EXTRACT:
• Each ticket type = ONE event_details object
• Correlate ticket name with description for full details

EXPECTED TEXT FORMATS:
• Title: "Aditya tripathi jan" → artist = "aditya tripathi"
• Description: "31st jan 1pm - Ishq hain" → day=31, month=1, start_time="01:00 PM", song="ishq hain"
• Description: "31st Jan 5pm - bananza" → day=31, month=1, start_time="05:00 PM", song="bananza"
• Ticket: "Bananza" with "₹850.00"

CORRELATION LOGIC:
• Ticket name "Bananza" matches description "bananza" (case-insensitive)
• Use description for date/time, ticket for price

PRICING FORMAT:
• Extract base price only: "₹850"
• EXCLUDE: "+₹21.25 ticket service fee" - DO NOT include this

IGNORE:
• "Guests" section
• "Time & Location" (only confirms Bangalore)
• Service fees
"""
```

### 1.3 Dance Inn (dance.inn.bangalore)

```python
"dance.inn.bangalore": """
═══════════════════════════════════════════════════════════════
STUDIO: DANCE INN (RAZORPAY)
═══════════════════════════════════════════════════════════════

WHERE TO LOOK:
1. Payment Details section (RIGHT side) → PRIMARY SOURCE
2. Title "{Artist} at Dance-Inn" → Artist name
3. Left schedule → IGNORE (validation only)

CRITICAL RULE:
**EACH payment line item = ONE separate event_details object**
A page with 10 line items MUST produce 10 event_details objects.

LINE ITEM FORMAT:
"{Song} by {Artist} on {Date} at {Time}" - ₹{Price}

PARSING EXAMPLES:
┌─────────────────────────────────────────────────────────────────────────┐
│ Line Item Text                                    │ Extracted Values     │
├─────────────────────────────────────────────────────────────────────────┤
│ "Mere rang Mai by Anvi Shetty on 23 Jan at 5pm"  │ song="mere rang mai" │
│                                                   │ by="anvi shetty"     │
│                                                   │ day=23, month=1      │
│                                                   │ start_time="05:00 PM"│
├─────────────────────────────────────────────────────────────────────────┤
│ "Mayya by Anvi Shetty on 23 Jan at 7pm"          │ song="mayya"         │
│                                                   │ by="anvi shetty"     │
│                                                   │ day=23, month=1      │
│                                                   │ start_time="07:00 PM"│
├─────────────────────────────────────────────────────────────────────────┤
│ "Chaudhary by Anvi Shetty on 24th Jan at 1pm"    │ song="chaudhary"     │
│                                                   │ by="anvi shetty"     │
│                                                   │ day=24, month=1      │
│                                                   │ start_time="01:00 PM"│
├─────────────────────────────────────────────────────────────────────────┤
│ "Desi girl by Anvi Shetty on 25th Jan at 11am"   │ song="desi girl"     │
│                                                   │ by="anvi shetty"     │
│                                                   │ day=25, month=1      │
│                                                   │ start_time="11:00 AM"│
└─────────────────────────────────────────────────────────────────────────┘

TIME NORMALIZATION FOR THIS STUDIO:
• "5pm" → "05:00 PM"
• "7pm" → "07:00 PM"
• "11am" → "11:00 AM"
• "1pm" → "01:00 PM"
• "3pm" → "03:00 PM"

PRICING:
• All items typically same price: "₹950"
• **EXCLUDE the "Service Fee" line completely** - this is NOT a workshop

IGNORE:
• Left side grouped schedule
• "(Optional)" text after line items
• Contact information
• Terms & Conditions
• "Service Fee ₹50.00" line
"""
```

### 1.4 DNA - Dance N Addiction (dance_n_addiction)

```python
"dance_n_addiction": """
═══════════════════════════════════════════════════════════════
STUDIO: DNA (YOACTIV)
═══════════════════════════════════════════════════════════════

WHERE TO LOOK:
1. "Session details" TABLE → PRIMARY SOURCE for song, date, time
2. "About Event" section → Pricing tiers
3. Poster → IGNORE (validation only)
4. Header metadata → IGNORE (often shows wrong time like 12:00 AM)

SESSION DETAILS TABLE FORMAT:
┌──────────────┬─────────┬───────────────────┐
│ Session Name │ Date    │ Time              │
├──────────────┼─────────┼───────────────────┤
│ Pal Pal      │ 07 Feb  │ 05:00 PM-07:00 PM │
│ Lapata       │ 07 Feb  │ 07:00 PM-09:00 PM │
└──────────────┴─────────┴───────────────────┘

• Each row = ONE event_details object
• Session Name = song (lowercase)
• Time already formatted correctly, just extract it

ARTIST EXTRACTION:
From title: "{Artist} _ {Date} Workshop"
Example: "Jordan _ 7th Feb Workshop" → by="jordan"
Extract everything before " _ "

ABOUT EVENT SECTION FORMAT:
"Date :- 7th Feb, Saturday"
"Time :- 5 to 7 pm .Song :- Pal Pal"
"Time :- 7 to 9 pm .Song :- Lapata"

"Fee :- Single Class"
"899/- First 15"
"999/- After that"
"1200/- OTS ."
"1599/- Both Class"

PRICING (SHARED across all sessions):
Convert fee section to: "₹899 (First 15)\\n₹999 (Regular)\\n₹1200 (OTS)\\nBoth Classes: ₹1599"
Apply this SAME pricing_info to ALL event_details from this page.

IGNORE:
• Header "Time: 12:00 AM - 12:00 AM" - this is WRONG, ignore it
• "Warm regards, DNA" signature
• Location details
"""
```

---

## 2. Complete Prompt Template

```python
STUDIO_EXTRACTION_HINTS = {
    "manifestbytmn": """...""",      # Section 1.1
    "vins.dance.co": """...""",      # Section 1.2
    "dance.inn.bangalore": """...""", # Section 1.3
    "dance_n_addiction": """...""",   # Section 1.4
}


def _generate_prompt(self, artists, current_date, studio_id=None):
    """Generate comprehensive AI prompt for workshop extraction."""

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
2. If INVALID or PAST event → is_valid=false, event_details=[]
3. If VALID → Extract ALL workshops as SEPARATE event_details objects

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

Examples (assuming today is January 22, 2026):
• "24 Jan" → year: 2026 (Jan 24 is future)
• "15 Jan" → year: 2027 (Jan 15 already passed)
• "7 Feb" → year: 2026 (Feb is future)
• "15 Dec" → year: 2026 (Dec is future)

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
• For multiple artists, check each name separately
• Add matched artist_id(s) to artist_id_list
• If no match found → empty array []

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

══════════════════════════════════════════════════════════════════════════════
SELF-VALIDATION CHECKLIST (verify before returning)
══════════════════════════════════════════════════════════════════════════════

□ is_valid is true ONLY for Bangalore dance events with future dates
□ event_type is exactly one of: "workshop", "intensive", "regulars"
□ EACH distinct song has its OWN event_details object
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

    # Add studio-specific hints
    if studio_id and studio_id in STUDIO_EXTRACTION_HINTS:
        prompt = f"{prompt}\n\n{STUDIO_EXTRACTION_HINTS[studio_id]}"

    return prompt
```

---

## 3. Implementation

### 3.1 Changes to `scripts/populate_workshops.py`

#### Step 1: Add Studio Hints (after line 43)

```python
# Add after AI_REQUEST_DELAY constant (line 43)

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
• Each session card = ONE event_details object
• Card contains: Song name (title), Date, Time, Duration, Price
• "Phase 1 (Active)" = session is available

EXPECTED TEXT FORMATS:
• Date: "Saturday, 24 January 2026" or "24th Jan" or "Jan 24"
• Time: "5:00 pm" with separate "Duration: 2 hours"
• When duration given: Calculate end_time = start_time + duration
  Example: "5:00 pm" + "2 hours" → start="05:00 PM", end="07:00 PM"
• Price: "₹850" per session, "₹1500" for combo

PRICING FORMAT:
Include both individual and combo pricing:
"₹850 per session\\nBoth sessions: ₹1500"

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
• Each ticket type = ONE event_details object
• Correlate ticket name with description for full details

EXPECTED TEXT FORMATS:
• Title: "Aditya tripathi jan" → artist = "aditya tripathi"
• Description: "31st jan 1pm - Ishq hain" → day=31, month=1, start_time="01:00 PM", song="ishq hain"
• Description: "31st Jan 5pm - bananza" → day=31, month=1, start_time="05:00 PM", song="bananza"
• Ticket: "Bananza" with "₹850.00"

CORRELATION: Match ticket names to descriptions (case-insensitive)

PRICING: Extract base price only "₹850", EXCLUDE "+₹21.25 ticket service fee"

IGNORE: "Guests" section, "Time & Location", service fees
""",

    "dance.inn.bangalore": """
═══════════════════════════════════════════════════════════════
STUDIO: DANCE INN (RAZORPAY)
═══════════════════════════════════════════════════════════════

WHERE TO LOOK:
1. Payment Details section (RIGHT side) → PRIMARY SOURCE
2. Title "{Artist} at Dance-Inn" → Artist name
3. Left schedule → IGNORE (validation only)

**CRITICAL: EACH payment line item = ONE separate event_details object**
10 line items = 10 event_details objects. NEVER merge them.

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

**EXCLUDE COMPLETELY: "Service Fee ₹50.00" line - this is NOT a workshop**

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

Each row = ONE event_details object

ARTIST: From title "{Artist} _ {Date} Workshop" → extract before " _ "
Example: "Jordan _ 7th Feb Workshop" → by="jordan"

ABOUT EVENT PRICING FORMAT:
"Fee :- Single Class"
"899/- First 15"
"999/- After that"
"1200/- OTS"
"1599/- Both Class"

Convert to: "₹899 (First 15)\\n₹999 (Regular)\\n₹1200 (OTS)\\nBoth Classes: ₹1599"

CRITICAL: Apply SAME pricing_info to ALL event_details from this page.

IGNORE: Header "Time: 12:00 AM - 12:00 AM", "Warm regards, DNA", location
"""
}
```

#### Step 2: Replace `_generate_prompt` method (lines 153-223)

Replace the entire `_generate_prompt` method with the new implementation from Section 2.

#### Step 3: Update method signatures

```python
# Line 141-151: Add studio_id parameter
@retry(max_attempts=3, backoff_factor=2, exceptions=(Exception,))
def analyze_with_ai(self, screenshot_path: str, artists_data: list = [], studio_id: str = None) -> Optional[EventSummary]:
    """Analyze workshop screenshot using the selected AI model."""
    if self.cfg.ai_model not in AI_MODEL_VERSIONS:
        raise ValueError(f"Unknown ai_model: {self.cfg.ai_model}")

    model_version = AI_MODEL_VERSIONS[self.cfg.ai_model]
    return self._analyze_with_ai(screenshot_path, artists_data=artists_data, model_version=model_version, studio_id=studio_id)


# Line 225: Add studio_id parameter
def _analyze_with_ai(
    self, screenshot_path: str, artists_data: list, model_version: str, studio_id: str = None
) -> Optional[EventSummary]:
    # ... existing code ...

    # Line 248: Pass studio_id to _generate_prompt
    response = self.client.beta.chat.completions.parse(
        model=model_version,
        messages=[
            {
                "role": "system",
                "content": self._generate_prompt(artists_data, date.today().strftime("%B %d, %Y"), studio_id),
            },
            # ... rest unchanged ...
        ],
        response_format=EventSummary,
    )
    # ... rest unchanged ...


# Line 103: Pass studio_id when calling analyze_with_ai
response = self.analyze_with_ai(screenshot_path, artists_data, studio_id=studio.config.studio_id)
```

### 3.2 Summary of Changes

| Location | Change |
|----------|--------|
| After line 43 | Add `STUDIO_EXTRACTION_HINTS` dictionary |
| Lines 153-223 | Replace `_generate_prompt` with new version |
| Line 142 | Add `studio_id: str = None` parameter |
| Line 151 | Pass `studio_id=studio_id` to `_analyze_with_ai` |
| Line 225 | Add `studio_id: str = None` parameter |
| Line 248 | Pass `studio_id` to `_generate_prompt` |
| Line 103 | Pass `studio_id=studio.config.studio_id` |

### 3.3 Backward Compatibility

All changes are backward compatible:
- `studio_id` defaults to `None`
- Without `studio_id`, base prompt works as before
- Data models unchanged
- Output format unchanged

---

## Quick Reference: What the AI Must Do

| Input Variation | AI Must Output |
|-----------------|----------------|
| "5pm" | "05:00 PM" |
| "11am" | "11:00 AM" |
| "1pm" | "01:00 PM" |
| "5-7pm" | start="05:00 PM", end="07:00 PM" |
| "24th Jan" | day=24, month=1 |
| "Jan 24" | day=24, month=1 |
| "Aadil X Krutika" | "aadil x krutika" |
| "Aadil & Krutika" | "aadil x krutika" |
| "Pal Pal" | "pal pal" |
| "₹950 + ₹50 fee" | "₹950" (exclude fee) |
| 10 payment items | 10 event_details |

---

*Document Version: Final (AI-Only)*
*Created: January 2026*
