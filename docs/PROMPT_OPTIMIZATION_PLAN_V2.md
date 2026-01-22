# AI Prompt Optimization Plan V2 - Fool-Proof Edition

## The Core Problem

```
┌─────────────────────────────────────────────────────────────┐
│  LAYOUT (Template-driven)     │  TEXT (Human-entered)       │
│  ✓ Consistent                 │  ✗ Inconsistent             │
│  ✓ Predictable sections       │  ✗ Variable formats         │
│  ✓ Same HTML structure        │  ✗ Typos & variations       │
│  ✓ Same visual hierarchy      │  ✗ Missing information      │
└─────────────────────────────────────────────────────────────┘
```

**Studio hints solve WHERE to look. This plan solves HOW to parse varied text.**

---

## Table of Contents

1. [Text Variation Analysis](#1-text-variation-analysis)
2. [Multi-Layer Extraction Strategy](#2-multi-layer-extraction-strategy)
3. [Comprehensive Variation Examples](#3-comprehensive-variation-examples)
4. [Fuzzy Matching & Normalization](#4-fuzzy-matching--normalization)
5. [Graceful Degradation Rules](#5-graceful-degradation-rules)
6. [Post-Processing Validation](#6-post-processing-validation)
7. [Updated Prompt with Variation Handling](#7-updated-prompt-with-variation-handling)
8. [Implementation Plan](#8-implementation-plan)

---

## 1. Text Variation Analysis

### 1.1 Time Format Variations (Real Examples)

| Category | Variations |
|----------|------------|
| **Simple** | `5pm`, `5 pm`, `5PM`, `5 PM`, `5p.m.`, `5 p.m.` |
| **With minutes** | `5:00pm`, `5:00 pm`, `5:00PM`, `5:00 PM`, `5.00pm`, `5.00 PM` |
| **Padded** | `05:00 PM`, `05:00pm` |
| **24-hour** | `17:00`, `17:00 hrs`, `1700` |
| **Range inline** | `5-7pm`, `5 to 7pm`, `5pm-7pm`, `5pm to 7pm`, `5-7 pm` |
| **Range spaced** | `5 pm - 7 pm`, `5:00 PM - 7:00 PM`, `5:00pm-7:00pm` |
| **Informal** | `5 onwards`, `from 5pm`, `starts 5`, `evening 5` |
| **Duration-based** | `5pm (2 hours)`, `5pm for 2hrs`, `5-7 (2hr session)` |
| **Abbreviated** | `5p`, `5a`, `5 evening`, `5 eve` |

### 1.2 Date Format Variations

| Category | Variations |
|----------|------------|
| **Day-Month** | `24 Jan`, `24 January`, `24th Jan`, `24th January` |
| **Month-Day** | `Jan 24`, `January 24`, `Jan 24th`, `January 24th` |
| **With year** | `24 Jan 2026`, `January 24, 2026`, `24/01/2026`, `2026-01-24` |
| **Numeric** | `24/01`, `01/24`, `24-01`, `24.01` |
| **With weekday** | `Saturday, 24 Jan`, `Sat 24th Jan`, `24 Jan (Saturday)` |
| **Weekday only** | `This Saturday`, `Next Friday`, `Coming Sunday` |
| **Ordinal** | `24th`, `1st`, `2nd`, `3rd`, `21st`, `22nd`, `23rd` |
| **Informal** | `tomorrow`, `day after`, `this weekend` |

### 1.3 Artist Name Variations

| Category | Variations |
|----------|------------|
| **Separators** | `A X B`, `A x B`, `A & B`, `A and B`, `A feat B`, `A featuring B`, `A with B`, `A ft B`, `A ft. B` |
| **Ordering** | `Aadil X Krutika` vs `Krutika X Aadil` |
| **Name forms** | `Aadil Khan`, `Aadil`, `AK`, `Aadil K` |
| **Typos** | `Adil Khan`, `Aadil kan`, `Aadil Kahn` |
| **Case** | `AADIL KHAN`, `aadil khan`, `Aadil Khan` |
| **Suffixes** | `Jordan`, `Jordan (DNA)`, `Jordan - DNA` |
| **Titles** | `Anvi Shetty`, `Ms. Anvi Shetty`, `Anvi Ma'am` |

### 1.4 Song Name Variations

| Category | Variations |
|----------|------------|
| **Case** | `Pal Pal`, `pal pal`, `PAL PAL`, `Pal pal` |
| **With movie** | `Pal Pal (Jalebi)`, `Pal Pal from Jalebi`, `Pal Pal - Jalebi` |
| **Full vs short** | `Pal Pal Dil Ke Paas` vs `Pal Pal` |
| **Typos** | `Pall Pall`, `Pal paal`, `Palpal` |
| **Transliteration** | `Ishq`, `Ishque`, `Ishq Hain`, `Ishq hai` |
| **Special chars** | `Crazy Kiya Re!`, `Desi Girl ❤️`, `Pal Pal 🎵` |

### 1.5 Pricing Variations

| Category | Variations |
|----------|------------|
| **Currency** | `₹850`, `Rs.850`, `Rs 850`, `INR 850`, `850/-`, `850 rupees` |
| **Early bird** | `First 15: 899`, `Early bird: 899`, `Phase 1: 899`, `Tier 1: 899`, `Early: 899` |
| **Regular** | `After: 999`, `Regular: 999`, `Phase 2: 999`, `Normal: 999` |
| **On spot** | `OTS: 1200`, `On the spot: 1200`, `Spot: 1200`, `At venue: 1200`, `Walk-in: 1200` |
| **Combo** | `Both: 1599`, `Combo: 1599`, `Package: 1599`, `2 classes: 1599`, `Full day: 1599` |
| **Per class** | `per session`, `per class`, `each`, `/class` |

---

## 2. Multi-Layer Extraction Strategy

### 2.1 The Fool-Proof Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    LAYER 1: AI EXTRACTION                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Comprehensive prompt with:                               ││
│  │ • Studio-specific WHERE hints (layout)                  ││
│  │ • Exhaustive variation examples (text patterns)         ││
│  │ • Normalization rules                                    ││
│  │ • Graceful degradation instructions                     ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                LAYER 2: POST-PROCESSING                      │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Python validation & normalization:                       ││
│  │ • Time format standardization                           ││
│  │ • Date validation & year inference                      ││
│  │ • Fuzzy artist name matching                            ││
│  │ • Price extraction cleanup                              ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 LAYER 3: VALIDATION                          │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Final checks:                                            ││
│  │ • Required fields present                               ││
│  │ • Logical consistency (end > start time)                ││
│  │ • Future date verification                              ││
│  │ • Confidence flagging for review                        ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Why Multi-Layer?

| Layer | Purpose | Handles |
|-------|---------|---------|
| **AI Extraction** | Primary intelligence | 80% of cases correctly |
| **Post-Processing** | Normalize & fix | AI output inconsistencies |
| **Validation** | Catch errors | Edge cases & logical errors |

---

## 3. Comprehensive Variation Examples

### 3.1 Time Parsing Examples (for prompt)

```
TIME EXTRACTION - Handle ALL these formats:

Input → Output (start_time, end_time)
────────────────────────────────────────
"5pm" → ("05:00 PM", null)
"5 pm" → ("05:00 PM", null)
"5PM" → ("05:00 PM", null)
"5:00pm" → ("05:00 PM", null)
"5:00 PM" → ("05:00 PM", null)
"05:00 PM" → ("05:00 PM", null)
"17:00" → ("05:00 PM", null)
"5p" → ("05:00 PM", null)
"5 evening" → ("05:00 PM", null)

"5-7pm" → ("05:00 PM", "07:00 PM")
"5 to 7pm" → ("05:00 PM", "07:00 PM")
"5pm-7pm" → ("05:00 PM", "07:00 PM")
"5pm to 7pm" → ("05:00 PM", "07:00 PM")
"5 pm - 7 pm" → ("05:00 PM", "07:00 PM")
"5:00 PM - 7:00 PM" → ("05:00 PM", "07:00 PM")
"5:00pm-7:00pm" → ("05:00 PM", "07:00 PM")
"05:00 PM to 07:00 PM" → ("05:00 PM", "07:00 PM")
"17:00-19:00" → ("05:00 PM", "07:00 PM")
"17:00 - 19:00" → ("05:00 PM", "07:00 PM")

"5pm (2 hours)" → ("05:00 PM", "07:00 PM")  // Calculate end
"5pm for 2hrs" → ("05:00 PM", "07:00 PM")   // Calculate end
"5 onwards" → ("05:00 PM", null)            // No end time

"11am" → ("11:00 AM", null)
"11:00 AM" → ("11:00 AM", null)
"11 am" → ("11:00 AM", null)
"11a" → ("11:00 AM", null)
"11 morning" → ("11:00 AM", null)

"1pm" → ("01:00 PM", null)
"1:00 PM" → ("01:00 PM", null)
"13:00" → ("01:00 PM", null)

RULES:
• Always output "HH:MM AM/PM" with leading zeros
• 12-hour format only in output
• If duration given, calculate end_time = start_time + duration
• If ambiguous (just "5"), assume PM for afternoon/evening events
• null for missing end_time is acceptable
```

### 3.2 Date Parsing Examples (for prompt)

```
DATE EXTRACTION - Handle ALL these formats:

Current date context: January 22, 2026

Input → Output (day, month, year)
────────────────────────────────────────
"24 Jan" → (24, 1, 2026)
"24 January" → (24, 1, 2026)
"24th Jan" → (24, 1, 2026)
"24th January" → (24, 1, 2026)
"Jan 24" → (24, 1, 2026)
"January 24" → (24, 1, 2026)
"Jan 24th" → (24, 1, 2026)
"January 24th" → (24, 1, 2026)

"24 Jan 2026" → (24, 1, 2026)
"January 24, 2026" → (24, 1, 2026)
"24/01/2026" → (24, 1, 2026)
"24-01-2026" → (24, 1, 2026)
"2026-01-24" → (24, 1, 2026)

"24/01" → (24, 1, 2026)           // Assume current year
"24-01" → (24, 1, 2026)
"24.01" → (24, 1, 2026)

"Saturday, 24 Jan" → (24, 1, 2026)
"Sat 24th Jan" → (24, 1, 2026)
"24 Jan (Saturday)" → (24, 1, 2026)
"Saturday, January 24, 2026" → (24, 1, 2026)

"7th Feb" → (7, 2, 2026)          // Future month, current year
"7 Feb" → (7, 2, 2026)
"Feb 7" → (7, 2, 2026)
"February 7th" → (7, 2, 2026)

"15 Dec" → (15, 12, 2026)         // December is ahead, use current year
"15 Dec 2025" → (15, 12, 2025)    // Explicit year, even if past

YEAR INFERENCE RULES:
• If year explicitly stated → use that year
• If month/day is TODAY or in FUTURE of current year → use current year
• If month/day is in PAST of current year → use next year
• Example (today is Jan 22, 2026):
  - "24 Jan" → 2026 (future, this year)
  - "15 Jan" → 2027 (past, next year)
  - "7 Feb" → 2026 (future, this year)
  - "15 Dec" → 2026 (future, this year)

ORDINAL HANDLING:
• "1st" → 1, "2nd" → 2, "3rd" → 3
• "4th" through "20th" → 4-20
• "21st" → 21, "22nd" → 22, "23rd" → 23
• "24th" through "31st" → 24-31
```

### 3.3 Artist Name Parsing Examples (for prompt)

```
ARTIST NAME EXTRACTION - Handle ALL these formats:

Input → Output (by field, lowercase)
────────────────────────────────────────
"Aadil Khan" → "aadil khan"
"AADIL KHAN" → "aadil khan"
"aadil khan" → "aadil khan"

MULTIPLE ARTISTS - All these mean the same:
"Aadil Khan X Krutika Solanki" → "aadil khan x krutika solanki"
"Aadil Khan x Krutika Solanki" → "aadil khan x krutika solanki"
"Aadil Khan & Krutika Solanki" → "aadil khan x krutika solanki"
"Aadil Khan and Krutika Solanki" → "aadil khan x krutika solanki"
"Aadil Khan feat Krutika Solanki" → "aadil khan x krutika solanki"
"Aadil Khan featuring Krutika Solanki" → "aadil khan x krutika solanki"
"Aadil Khan with Krutika Solanki" → "aadil khan x krutika solanki"
"Aadil Khan ft Krutika Solanki" → "aadil khan x krutika solanki"
"Aadil Khan ft. Krutika Solanki" → "aadil khan x krutika solanki"

RULES:
• Always output lowercase
• Always use " x " as separator for multiple artists
• Strip suffixes like "(DNA)", "- Studio Name", "Ma'am", "Sir"
• Handle any order: "A x B" and "B x A" are equivalent
• For artist_id matching: match against artist database provided

ARTIST DATABASE MATCHING:
• Compare extracted name against artists list
• Match should be case-insensitive
• Match first name if full name not in database
• If "Anvi Shetty" not found, try "Anvi"
• If no match found, artist_id_list = []
```

### 3.4 Pricing Parsing Examples (for prompt)

```
PRICING EXTRACTION - Handle ALL these formats:

CURRENCY SYMBOLS (all equivalent):
"₹850" = "Rs.850" = "Rs 850" = "INR 850" = "850/-" = "850 rupees"

TIERED PRICING - Extract ALL tiers:

Input text:
"Fee :- Single Class
899/- First 15
999/- After that
1200/- OTS
1599/- Both Class"

→ pricing_info: "₹899 (First 15)\n₹999 (Regular)\n₹1200 (OTS)\nBoth Classes: ₹1599"

TIER NAME MAPPING:
"First 15" / "Early bird" / "Phase 1" / "Tier 1" / "Early" → "(First 15)" or "(Early Bird)"
"After" / "Regular" / "Phase 2" / "Normal" / "Standard" → "(Regular)"
"OTS" / "On the spot" / "Spot" / "At venue" / "Walk-in" / "Door" → "(OTS)"
"Both" / "Combo" / "Package" / "2 classes" / "Full day" / "All sessions" → "Both/Combo: ₹X"

SIMPLE PRICING:
"₹950" → pricing_info: "₹950"
"Rs. 850 per session" → pricing_info: "₹850 per session"
"850/- each" → pricing_info: "₹850 each"

EXCLUSIONS (do NOT include):
• "Service Fee", "Convenience Fee", "Booking Fee"
• "GST", "Tax", "+18% GST"
• "+₹21.25 ticket service fee"
• "Platform fee"

OUTPUT FORMAT:
• Always use ₹ symbol
• Separate tiers with \n (newline)
• Include tier name in parentheses
• For combo, use "Both/Combo: ₹X" format
```

---

## 4. Fuzzy Matching & Normalization

### 4.1 Post-Processing: Time Normalization (Python)

```python
import re
from datetime import datetime, timedelta

def normalize_time(time_str: str) -> tuple[str | None, str | None]:
    """
    Normalize any time format to "HH:MM AM/PM".
    Returns (start_time, end_time) tuple.
    """
    if not time_str:
        return None, None

    time_str = time_str.lower().strip()

    # Patterns for single time
    single_patterns = [
        r'(\d{1,2}):(\d{2})\s*(am|pm|a\.m\.|p\.m\.)',  # 5:00 PM
        r'(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)',           # 5pm
        r'(\d{1,2}):(\d{2})',                            # 17:00 (24hr)
        r'(\d{1,2})\s*(morning|evening|eve)',           # 5 evening
    ]

    # Patterns for time range
    range_patterns = [
        r'(\d{1,2}):?(\d{2})?\s*(am|pm)?\s*[-–to]+\s*(\d{1,2}):?(\d{2})?\s*(am|pm)',
        r'(\d{1,2})\s*[-–to]+\s*(\d{1,2})\s*(am|pm)',
    ]

    # Try range patterns first
    for pattern in range_patterns:
        match = re.search(pattern, time_str)
        if match:
            start, end = parse_range_match(match)
            return format_time(start), format_time(end)

    # Try single time patterns
    for pattern in single_patterns:
        match = re.search(pattern, time_str)
        if match:
            time = parse_single_match(match)
            return format_time(time), None

    # Check for duration
    duration_match = re.search(r'(\d+)\s*(hours?|hrs?)', time_str)
    if duration_match:
        # Find start time and add duration
        # ... implementation
        pass

    return None, None

def format_time(hour: int, minute: int = 0, is_pm: bool = False) -> str:
    """Format to HH:MM AM/PM with leading zeros."""
    if hour > 12:
        hour -= 12
        is_pm = True
    elif hour == 12:
        is_pm = True
    elif hour == 0:
        hour = 12
        is_pm = False

    period = "PM" if is_pm else "AM"
    return f"{hour:02d}:{minute:02d} {period}"
```

### 4.2 Post-Processing: Fuzzy Artist Matching (Python)

```python
from difflib import SequenceMatcher
from typing import List, Dict, Optional

def fuzzy_match_artist(
    extracted_name: str,
    artists_db: List[Dict],
    threshold: float = 0.8
) -> Optional[str]:
    """
    Fuzzy match extracted artist name against database.
    Returns artist_id if match found, None otherwise.
    """
    if not extracted_name:
        return None

    extracted_lower = extracted_name.lower().strip()

    # Try exact match first
    for artist in artists_db:
        if artist['artist_name'].lower() == extracted_lower:
            return artist['artist_id']

    # Try fuzzy match
    best_match = None
    best_score = 0

    for artist in artists_db:
        db_name = artist['artist_name'].lower()

        # Full name similarity
        score = SequenceMatcher(None, extracted_lower, db_name).ratio()

        # Also try first name match
        extracted_first = extracted_lower.split()[0] if extracted_lower else ""
        db_first = db_name.split()[0] if db_name else ""
        first_name_score = SequenceMatcher(None, extracted_first, db_first).ratio()

        # Take the better score
        final_score = max(score, first_name_score * 0.9)  # Slight penalty for first-name-only

        if final_score > best_score and final_score >= threshold:
            best_score = final_score
            best_match = artist['artist_id']

    return best_match

def match_multiple_artists(
    by_field: str,
    artists_db: List[Dict]
) -> List[str]:
    """
    Handle multiple artists separated by various delimiters.
    Returns list of matched artist_ids.
    """
    if not by_field:
        return []

    # Split by common separators
    separators = [' x ', ' X ', ' & ', ' and ', ' feat ', ' featuring ', ' with ', ' ft ', ' ft. ']

    names = [by_field]
    for sep in separators:
        new_names = []
        for name in names:
            new_names.extend(name.split(sep))
        names = new_names

    # Match each name
    artist_ids = []
    for name in names:
        name = name.strip()
        if name:
            artist_id = fuzzy_match_artist(name, artists_db)
            if artist_id and artist_id not in artist_ids:
                artist_ids.append(artist_id)

    return artist_ids
```

### 4.3 Post-Processing: Price Normalization (Python)

```python
import re

def normalize_pricing(pricing_str: str) -> str:
    """
    Normalize pricing to consistent format.
    Excludes service fees, GST, etc.
    """
    if not pricing_str:
        return None

    # Remove service fees, GST, etc.
    exclusions = [
        r'\+\s*₹?\d+\.?\d*\s*(service fee|ticket fee|convenience fee|booking fee)',
        r'\+?\s*\d+%?\s*(gst|tax)',
        r'platform fee[:\s]*₹?\d+',
    ]

    cleaned = pricing_str
    for pattern in exclusions:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE)

    # Normalize currency symbols
    cleaned = re.sub(r'(Rs\.?|INR|rupees)\s*', '₹', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'(\d+)/-', r'₹\1', cleaned)

    # Ensure ₹ symbol before numbers
    cleaned = re.sub(r'(?<![₹\d])(\d{3,4})(?!\d)', r'₹\1', cleaned)

    return cleaned.strip()

def extract_price_tiers(text: str) -> str:
    """
    Extract and format all pricing tiers from text.
    """
    tiers = []

    # Patterns for different tiers
    patterns = {
        'early': r'(first\s*\d+|early\s*bird|phase\s*1|tier\s*1|early)[:\s]*₹?(\d+)',
        'regular': r'(after|regular|phase\s*2|normal|standard)[:\s]*₹?(\d+)',
        'ots': r'(ots|on\s*the\s*spot|spot|walk[-\s]*in|at\s*venue|door)[:\s]*₹?(\d+)',
        'combo': r'(both|combo|package|all\s*sessions?|full\s*day|\d+\s*classes?)[:\s]*₹?(\d+)',
    }

    text_lower = text.lower()

    for tier_type, pattern in patterns.items():
        match = re.search(pattern, text_lower)
        if match:
            price = match.group(2)
            if tier_type == 'early':
                tiers.append(f"₹{price} (Early Bird)")
            elif tier_type == 'regular':
                tiers.append(f"₹{price} (Regular)")
            elif tier_type == 'ots':
                tiers.append(f"₹{price} (OTS)")
            elif tier_type == 'combo':
                tiers.append(f"Both/Combo: ₹{price}")

    # If no tiers found, try to extract single price
    if not tiers:
        single_price = re.search(r'₹(\d+)', text)
        if single_price:
            tiers.append(f"₹{single_price.group(1)}")

    return '\n'.join(tiers) if tiers else None
```

---

## 5. Graceful Degradation Rules

### 5.1 What to do when information is missing

| Missing Field | Graceful Handling |
|---------------|-------------------|
| **end_time** | Set to `null` - acceptable |
| **year** | Infer from current date (future = this year, past = next year) |
| **song** | Use event title or "Workshop by {Artist}" |
| **pricing_info** | Set to `null` - will need manual entry |
| **artist_id_list** | Empty array `[]` - no match found |
| **by (artist)** | Extract from title or any "by {name}" text |
| **day/month** | Cannot proceed - mark `is_valid: false` |

### 5.2 Confidence Scoring

```python
def calculate_confidence(event_details: dict) -> float:
    """
    Calculate confidence score for extracted data.
    Returns 0.0 to 1.0
    """
    score = 0.0
    max_score = 0.0

    # Required fields
    checks = [
        ('time_details', 0.3, lambda x: x and len(x) > 0),
        ('day', 0.15, lambda x: x.get('time_details', [{}])[0].get('day') is not None),
        ('month', 0.15, lambda x: x.get('time_details', [{}])[0].get('month') is not None),
        ('start_time', 0.1, lambda x: x.get('time_details', [{}])[0].get('start_time') is not None),
        ('by', 0.1, lambda x: x.get('by') is not None),
        ('song', 0.1, lambda x: x.get('song') is not None),
        ('pricing_info', 0.05, lambda x: x.get('pricing_info') is not None),
        ('artist_id_list', 0.05, lambda x: len(x.get('artist_id_list', [])) > 0),
    ]

    for field, weight, check in checks:
        max_score += weight
        if check(event_details):
            score += weight

    return score / max_score if max_score > 0 else 0.0

# Flag events with confidence < 0.7 for manual review
```

### 5.3 Fallback Extraction Strategies

```
IF primary extraction fails, TRY these fallbacks:

1. TIME FALLBACK:
   Primary: Look for explicit time in structured section
   Fallback 1: Look for time in poster/image text
   Fallback 2: Look for duration and calculate
   Fallback 3: Return null, flag for review

2. DATE FALLBACK:
   Primary: Look for explicit date in structured section
   Fallback 1: Look for weekday and infer upcoming date
   Fallback 2: Look for "this Saturday" type references
   Fallback 3: Check URL slug for date hints
   Fallback 4: Mark is_valid: false (cannot proceed without date)

3. ARTIST FALLBACK:
   Primary: Look for "by {name}" pattern
   Fallback 1: Look for "Workshop with {name}"
   Fallback 2: Extract from page title
   Fallback 3: Extract from payment line items
   Fallback 4: Return null (acceptable)

4. SONG FALLBACK:
   Primary: Look for song name in session/ticket info
   Fallback 1: Look for "routine: {song}" pattern
   Fallback 2: Extract from title if single workshop
   Fallback 3: Return null (acceptable for some events)

5. PRICING FALLBACK:
   Primary: Look for ₹/Rs. with number
   Fallback 1: Look for "fee" or "price" sections
   Fallback 2: Look for tiered pricing patterns
   Fallback 3: Return null (will need manual entry)
```

---

## 6. Post-Processing Validation

### 6.1 Validation Rules (Python)

```python
from datetime import datetime, date
import pytz

def validate_event_details(event_data: dict, current_date: date) -> tuple[bool, list[str]]:
    """
    Validate extracted event details.
    Returns (is_valid, list_of_errors)
    """
    errors = []

    # Check required fields
    if not event_data.get('event_details'):
        errors.append("No event_details extracted")
        return False, errors

    for i, detail in enumerate(event_data['event_details']):
        prefix = f"event_details[{i}]"

        # Validate time_details
        time_details = detail.get('time_details', [])
        if not time_details:
            errors.append(f"{prefix}: Missing time_details")
            continue

        for j, td in enumerate(time_details):
            td_prefix = f"{prefix}.time_details[{j}]"

            # Check date components
            day = td.get('day')
            month = td.get('month')
            year = td.get('year')

            if day is None or month is None:
                errors.append(f"{td_prefix}: Missing day or month")
                continue

            # Validate date range
            if not (1 <= day <= 31):
                errors.append(f"{td_prefix}: Invalid day {day}")
            if not (1 <= month <= 12):
                errors.append(f"{td_prefix}: Invalid month {month}")

            # Check if date is in past
            if year:
                try:
                    event_date = date(year, month, day)
                    if event_date < current_date:
                        errors.append(f"{td_prefix}: Event date {event_date} is in the past")
                except ValueError as e:
                    errors.append(f"{td_prefix}: Invalid date - {e}")

            # Validate time format
            start_time = td.get('start_time')
            end_time = td.get('end_time')

            if start_time:
                if not validate_time_format(start_time):
                    errors.append(f"{td_prefix}: Invalid start_time format '{start_time}'")

            if end_time:
                if not validate_time_format(end_time):
                    errors.append(f"{td_prefix}: Invalid end_time format '{end_time}'")

                # Check end > start
                if start_time and end_time:
                    if not is_end_after_start(start_time, end_time):
                        errors.append(f"{td_prefix}: end_time must be after start_time")

        # Validate lowercase fields
        by_field = detail.get('by')
        if by_field and by_field != by_field.lower():
            errors.append(f"{prefix}: 'by' field should be lowercase")

        song_field = detail.get('song')
        if song_field and song_field != song_field.lower():
            errors.append(f"{prefix}: 'song' field should be lowercase")

    return len(errors) == 0, errors

def validate_time_format(time_str: str) -> bool:
    """Check if time is in HH:MM AM/PM format."""
    import re
    pattern = r'^(0[1-9]|1[0-2]):[0-5][0-9] (AM|PM)$'
    return bool(re.match(pattern, time_str))

def is_end_after_start(start: str, end: str) -> bool:
    """Check if end time is after start time."""
    from datetime import datetime
    start_dt = datetime.strptime(start, "%I:%M %p")
    end_dt = datetime.strptime(end, "%I:%M %p")
    return end_dt > start_dt
```

### 6.2 Auto-Correction Rules

```python
def auto_correct_event_details(event_data: dict, artists_db: list) -> dict:
    """
    Auto-correct common issues in extracted data.
    """
    corrected = event_data.copy()

    for detail in corrected.get('event_details', []):
        # Lowercase 'by' and 'song'
        if detail.get('by'):
            detail['by'] = detail['by'].lower().strip()
        if detail.get('song'):
            detail['song'] = detail['song'].lower().strip()

        # Normalize artist separator
        if detail.get('by'):
            for sep in [' & ', ' and ', ' feat ', ' featuring ', ' with ', ' ft ', ' ft. ', ' X ']:
                detail['by'] = detail['by'].replace(sep.lower(), ' x ')

        # Re-run fuzzy artist matching
        if detail.get('by'):
            detail['artist_id_list'] = match_multiple_artists(detail['by'], artists_db)

        # Normalize pricing
        if detail.get('pricing_info'):
            detail['pricing_info'] = normalize_pricing(detail['pricing_info'])

        # Normalize times
        for td in detail.get('time_details', []):
            if td.get('start_time'):
                td['start_time'] = normalize_single_time(td['start_time'])
            if td.get('end_time'):
                td['end_time'] = normalize_single_time(td['end_time'])

    return corrected

def normalize_single_time(time_str: str) -> str:
    """Ensure time is in HH:MM AM/PM format."""
    if not time_str:
        return None

    # Already correct format
    if validate_time_format(time_str):
        return time_str

    # Try to parse and reformat
    import re

    # Handle "5:00 pm" -> "05:00 PM"
    match = re.match(r'(\d{1,2}):(\d{2})\s*(am|pm)', time_str.lower())
    if match:
        hour, minute, period = match.groups()
        return f"{int(hour):02d}:{minute} {period.upper()}"

    # Handle "5 pm" -> "05:00 PM"
    match = re.match(r'(\d{1,2})\s*(am|pm)', time_str.lower())
    if match:
        hour, period = match.groups()
        return f"{int(hour):02d}:00 {period.upper()}"

    return time_str  # Return as-is if can't parse
```

---

## 7. Updated Prompt with Variation Handling

### 7.1 Complete Fool-Proof Prompt

```python
STUDIO_EXTRACTION_HINTS = {
    "manifestbytmn": """
═══════════════════════════════════════════════════════════════
STUDIO: MANIFEST BY TMN
═══════════════════════════════════════════════════════════════
WHERE TO LOOK (Layout):
• Session cards on RIGHT side = PRIMARY SOURCE
• Each card has: Song, Date, Time, Duration, Price
• Header "by {Artist}" = Artist name
• Poster on LEFT = Validation only

TEXT VARIATIONS TO EXPECT:
• Date: "Saturday, 24 January 2026" or "24th Jan" or "Jan 24"
• Time: "5:00 pm" with "Duration: 2 hours" - CALCULATE end_time
• Price: Individual (₹850) + Combo option (₹1500)
• Multiple sessions = Multiple event_details
""",

    "vins.dance.co": """
═══════════════════════════════════════════════════════════════
STUDIO: VINS DANCE CO
═══════════════════════════════════════════════════════════════
WHERE TO LOOK (Layout):
• "Tickets" section = PRIMARY SOURCE (song names, prices)
• Header description = Date/time ("31st jan 1pm - Ishq hain")
• Title = Artist name

TEXT VARIATIONS TO EXPECT:
• Description: "{date} {time} - {song}" e.g., "31st jan 1pm - Ishq hain"
• Ticket names may differ in case: "Bananza" vs "bananza"
• Time format: "1pm", "5pm" (no leading zero, no minutes)
• EXCLUDE: "+₹21.25 ticket service fee"
• Match ticket names to description (case-insensitive)
""",

    "dance.inn.bangalore": """
═══════════════════════════════════════════════════════════════
STUDIO: DANCE INN (RAZORPAY)
═══════════════════════════════════════════════════════════════
WHERE TO LOOK (Layout):
• Payment Details section (RIGHT) = PRIMARY SOURCE
• EACH line item = ONE separate workshop
• Title "{Artist} at Dance-Inn" = Artist name

TEXT VARIATIONS TO EXPECT:
• Line item format: "{Song} by {Artist} on {Date} at {Time}"
• Examples:
  - "Mere rang Mai by Anvi Shetty on 23 Jan at 5pm"
  - "Chaudhary by Anvi Shetty on 24th Jan at 1pm"
  - "Desi girl by Anvi Shetty on 25th Jan at 11am"
• Time: "5pm", "7pm", "11am", "1pm", "3pm" → Normalize to "05:00 PM" etc.
• Date: "23 Jan", "24th Jan" → Extract day and month
• CRITICAL: 10 line items = 10 event_details objects
• EXCLUDE: "Service Fee" line entirely
""",

    "dance_n_addiction": """
═══════════════════════════════════════════════════════════════
STUDIO: DNA (YOACTIV)
═══════════════════════════════════════════════════════════════
WHERE TO LOOK (Layout):
• "Session details" TABLE = PRIMARY SOURCE (song, date, time)
• "About Event" section = Pricing tiers
• Poster = Validation only

TEXT VARIATIONS TO EXPECT:
• Table format: Session Name | Date | Time
  - "Pal Pal | 07 Feb | 05:00 PM-07:00 PM"
• About section:
  - "Date :- 7th Feb, Saturday"
  - "Time :- 5 to 7 pm .Song :- Pal Pal"
  - "Fee :- Single Class"
  - "899/- First 15"
  - "999/- After that"
  - "1200/- OTS"
  - "1599/- Both Class"
• Artist from title: "{Artist} _ {Date} Workshop" → Before " _ "
• SHARED pricing across all sessions
• Header metadata often WRONG (12:00 AM) - IGNORE IT
"""
}


def _generate_prompt(self, artists, current_date, studio_id=None):
    """Generate fool-proof prompt with comprehensive variation handling."""

    base_prompt = f"""You are an expert data extraction system for dance workshop events.
Your task is to extract structured information from a screenshot, handling various text formats.

══════════════════════════════════════════════════════════════════
CONTEXT
══════════════════════════════════════════════════════════════════

Artists Database: {artists}
Current Date: {current_date}

══════════════════════════════════════════════════════════════════
TASK
══════════════════════════════════════════════════════════════════

1. Determine if this is a valid Bangalore-based dance event
2. If NOT valid OR past event → is_valid=false, empty event_details
3. If VALID → Extract ALL workshops as separate event_details

══════════════════════════════════════════════════════════════════
TIME EXTRACTION - Handle ALL variations
══════════════════════════════════════════════════════════════════

OUTPUT FORMAT: Always "HH:MM AM/PM" with leading zeros

Input Examples → Output:
• "5pm", "5 pm", "5PM" → "05:00 PM"
• "5:00pm", "5:00 PM" → "05:00 PM"
• "11am", "11 am" → "11:00 AM"
• "1pm" → "01:00 PM"
• "17:00" (24hr) → "05:00 PM"
• "5-7pm" → start="05:00 PM", end="07:00 PM"
• "5 to 7pm" → start="05:00 PM", end="07:00 PM"
• "5pm-7pm" → start="05:00 PM", end="07:00 PM"
• "5:00 PM - 7:00 PM" → start="05:00 PM", end="07:00 PM"
• "05:00 PM-07:00 PM" → start="05:00 PM", end="07:00 PM"
• "5pm (2 hours)" → start="05:00 PM", end="07:00 PM" (calculated)
• If only start time available → end_time = null

══════════════════════════════════════════════════════════════════
DATE EXTRACTION - Handle ALL variations
══════════════════════════════════════════════════════════════════

Input Examples → Output (day, month):
• "24 Jan", "24 January", "24th Jan" → day=24, month=1
• "Jan 24", "January 24th" → day=24, month=1
• "7th Feb", "Feb 7" → day=7, month=2
• "Saturday, 24 January 2026" → day=24, month=1, year=2026
• "24/01" → day=24, month=1

YEAR INFERENCE (current date: {current_date}):
• Year explicitly stated → use that year
• Date is today or future this year → use current year
• Date is past this year → use next year

ORDINALS: 1st=1, 2nd=2, 3rd=3, 4th=4, ..., 21st=21, 22nd=22, 23rd=23, 24th=24, ...

══════════════════════════════════════════════════════════════════
ARTIST NAME - Handle ALL variations
══════════════════════════════════════════════════════════════════

OUTPUT: Always lowercase, use " x " for multiple artists

Separators to recognize (all become " x "):
• " X ", " x " → " x "
• " & ", " and " → " x "
• " feat ", " featuring ", " ft ", " ft. " → " x "
• " with " → " x "

Examples:
• "Aadil Khan X Krutika Solanki" → "aadil khan x krutika solanki"
• "Aadil & Krutika" → "aadil x krutika"
• "Jordan" → "jordan"
• "Anvi Shetty" → "anvi shetty"

ARTIST MATCHING: Compare against artists database (case-insensitive)

══════════════════════════════════════════════════════════════════
SONG NAME - Handle ALL variations
══════════════════════════════════════════════════════════════════

OUTPUT: Always lowercase

• "Pal Pal", "PAL PAL", "pal pal" → "pal pal"
• "Ishq Hain", "ishq hain" → "ishq hain"
• Remove emojis: "Desi Girl ❤️" → "desi girl"
• Keep movie reference if present: "pal pal (jalebi)" → "pal pal (jalebi)"

══════════════════════════════════════════════════════════════════
PRICING - Handle ALL variations
══════════════════════════════════════════════════════════════════

CURRENCY (all equivalent): ₹850 = Rs.850 = Rs 850 = INR 850 = 850/- = 850 rupees
OUTPUT: Always use ₹ symbol

TIERS to recognize:
• "First 15" / "Early bird" / "Phase 1" → include as "(Early Bird)" or "(First 15)"
• "After" / "Regular" / "Phase 2" → include as "(Regular)"
• "OTS" / "On the spot" / "Spot" / "Walk-in" → include as "(OTS)"
• "Both" / "Combo" / "Package" / "All sessions" → include as "Both/Combo: ₹X"

Format multiple tiers with \\n:
"₹899 (First 15)\\n₹999 (Regular)\\n₹1200 (OTS)\\nBoth: ₹1599"

EXCLUDE from pricing_info:
• Service fees, convenience fees, booking fees
• GST, tax percentages
• "+₹XX ticket service fee"

══════════════════════════════════════════════════════════════════
MULTIPLE WORKSHOPS
══════════════════════════════════════════════════════════════════

CRITICAL: Each distinct song/routine = SEPARATE event_details object

• Artist with 3 different songs = 3 event_details
• Same song on different dates = SEPARATE event_details
• Payment page with 10 line items = 10 event_details

══════════════════════════════════════════════════════════════════
GRACEFUL HANDLING (when info missing)
══════════════════════════════════════════════════════════════════

• Missing end_time → null (acceptable)
• Missing year → infer from current date
• Missing song → null or extract from title
• Missing pricing → null
• Missing artist_id match → empty array []
• Missing day/month → CANNOT proceed, is_valid=false

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

VALIDATION before returning:
□ All times in "HH:MM AM/PM" format with leading zeros
□ All 'by' and 'song' fields are lowercase
□ Each distinct song has its own event_details
□ Pricing excludes service fees
□ Dates are in the future

Return ONLY raw JSON. No explanations."""

    # Add studio-specific hints if available
    if studio_id and studio_id in STUDIO_EXTRACTION_HINTS:
        base_prompt = f"{base_prompt}\n\n{STUDIO_EXTRACTION_HINTS[studio_id]}"

    return base_prompt
```

---

## 8. Implementation Plan

### 8.1 Changes Summary

| Component | Change Type | Description |
|-----------|-------------|-------------|
| `STUDIO_EXTRACTION_HINTS` | Add | Studio-specific WHERE + text variation hints |
| `_generate_prompt()` | Replace | New fool-proof prompt with variation examples |
| `analyze_with_ai()` | Modify | Add `studio_id` parameter |
| `_analyze_with_ai()` | Modify | Pass `studio_id` to prompt generator |
| `process_link()` | Modify | Pass `studio.config.studio_id` |
| **NEW** `post_processor.py` | Add | Time/date normalization, fuzzy matching, validation |
| `StudioProcessor.process_studio()` | Modify | Add post-processing step |

### 8.2 File Changes

#### File 1: `scripts/populate_workshops.py`

```python
# After line 43 (AI_REQUEST_DELAY), add:
STUDIO_EXTRACTION_HINTS = { ... }  # As defined above

# Replace lines 153-223 (_generate_prompt) with new implementation

# Modify line 89-132 (process_link):
def process_link(self, link: str, studio: Any, version: int = 0, artists_data: list = []) -> Optional[Dict]:
    # ... existing code ...

    # Line ~103: Pass studio_id
    response = self.analyze_with_ai(screenshot_path, artists_data, studio_id=studio.config.studio_id)

    # After response, add post-processing:
    if response:
        response = post_process_response(response, artists_data)
        response = validate_and_correct(response)

    # ... rest of existing code ...

# Modify line 141-151 (analyze_with_ai):
@retry(max_attempts=3, backoff_factor=2, exceptions=(Exception,))
def analyze_with_ai(self, screenshot_path: str, artists_data: list = [], studio_id: str = None) -> Optional[EventSummary]:
    # ... existing code ...
    return self._analyze_with_ai(screenshot_path, artists_data, model_version, studio_id)

# Modify line 225-300 (_analyze_with_ai):
def _analyze_with_ai(self, screenshot_path: str, artists_data: list, model_version: str, studio_id: str = None) -> Optional[EventSummary]:
    # ... existing code ...
    # Line ~248: Pass studio_id
    "content": self._generate_prompt(artists_data, date.today().strftime("%B %d, %Y"), studio_id),
    # ... rest of existing code ...
```

#### File 2: `scripts/post_processor.py` (NEW)

```python
"""
Post-processing module for workshop data extraction.
Handles normalization, fuzzy matching, and validation.
"""

import re
from datetime import datetime, date
from difflib import SequenceMatcher
from typing import List, Dict, Optional, Tuple

# Include all functions from Section 4 and 6:
# - normalize_time()
# - fuzzy_match_artist()
# - match_multiple_artists()
# - normalize_pricing()
# - extract_price_tiers()
# - validate_event_details()
# - auto_correct_event_details()
# - validate_time_format()
# - is_end_after_start()
# - normalize_single_time()
# - calculate_confidence()

def post_process_response(response: dict, artists_db: List[Dict]) -> dict:
    """Main post-processing function."""
    if not response or not response.get('event_details'):
        return response

    # Auto-correct common issues
    response = auto_correct_event_details(response, artists_db)

    return response

def validate_and_correct(response: dict) -> dict:
    """Validate and flag low-confidence extractions."""
    if not response or not response.get('event_details'):
        return response

    for detail in response['event_details']:
        confidence = calculate_confidence(detail)
        detail['_confidence'] = confidence  # Internal field for debugging

        if confidence < 0.7:
            detail['_needs_review'] = True

    return response
```

### 8.3 Testing Checklist

| Test Case | Input | Expected Output |
|-----------|-------|-----------------|
| Time "5pm" | "5pm" | "05:00 PM" |
| Time "11am" | "11am" | "11:00 AM" |
| Time range | "5-7pm" | start="05:00 PM", end="07:00 PM" |
| Date ordinal | "24th Jan" | day=24, month=1 |
| Artist multiple | "A X B" | "a x b" |
| Artist fuzzy | "Adil Khan" (typo) | Match to "Aadil Khan" |
| Price tiers | "899/- First 15" | "₹899 (First 15)" |
| Price exclusion | "₹950 + ₹50 service fee" | "₹950" |
| Dance Inn 10 items | 10 line items | 10 event_details |
| DNA shared pricing | 2 songs, 1 pricing block | Both have same pricing_info |

### 8.4 Rollout Plan

1. **Phase 1**: Implement prompt changes only (low risk)
2. **Phase 2**: Add post-processing validation (catches AI errors)
3. **Phase 3**: Add fuzzy artist matching (improves artist_id coverage)
4. **Phase 4**: Add confidence scoring (flags issues for review)

---

## Summary: What Makes This Fool-Proof

| Problem | Solution |
|---------|----------|
| Layout varies by studio | Studio-specific WHERE hints |
| Text format varies by human | Exhaustive variation examples in prompt |
| AI might output wrong format | Post-processing normalization |
| Artist names have typos | Fuzzy matching with 80% threshold |
| Missing information | Graceful degradation rules |
| Logical errors | Validation layer catches them |
| Low confidence extractions | Flagged for manual review |

**The 3-layer architecture ensures:**
1. **AI does its best** with comprehensive prompt
2. **Code fixes** what AI gets slightly wrong
3. **Validation catches** what code can't fix

---

*Document Version: 2.0 (Fool-Proof Edition)*
*Created: January 2026*
