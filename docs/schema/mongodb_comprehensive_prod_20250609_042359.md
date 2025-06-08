# MongoDB Schema Documentation - Nachna Dance App

**Generated:** 2025-06-08 22:53:59 UTC
**Environment:** prod

## Overview

This document provides a comprehensive overview of all MongoDB collections in the Nachna Dance App.

## Database: `dance_app`

### Collection: `users`

**Purpose:** Stores user account information, authentication data, and profile details
**Documents:** 21
**Fields:** 12

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `6842ee7a46d995c2ca95e65c`, `6842e68a30d85de5f6bcbd82` |
| `mobile_number` | string | 0.0% | User's mobile phone number for authentication | `7989287766`, `8384014344` |
| `password_hash` | string | 0.0% | Hashed password for secure authentication | `$2b$12$8Qa8gKpASkTw9gQMX8iv8eueyC58KJku1rjah6/f5QtsYW3KONdS.`, `$2b$12$/5I8Yv4EAfult466RDj9veJMe6eIg.oQehwdeOUubVNy2IeVxkwZq` |
| `name` | string, null | 19.05% | User's display name | `Navya`, `bdbsbd` |
| `date_of_birth` | string, null | 19.05% | User's birth date | `1997-09-27`, `2007-06-11` |
| `gender` | string, null | 19.05% | User's gender identity | `female`, `male` |
| `profile_complete` | boolean | 0.0% | Boolean flag indicating if user profile is complete | `False`, `True` |
| `is_admin` | boolean | 0.0% | Boolean flag for admin privileges | `False`, `True` |
| `created_at` | datetime | 0.0% | Timestamp when document was created | `2025-06-06T13:34:50.186000`, `2025-06-06T13:00:58.473000` |
| `updated_at` | datetime | 0.0% | Timestamp when document was last modified | `2025-06-06T13:34:50.186000`, `2025-06-06T13:01:27.801000` |
| `profile_picture_id` | string | 0.0% | Field purpose not documented | `6842e6979f0fefa378038b60`, `68421788e15954f670462de5` |
| `profile_picture_url` | string | 0.0% | Field purpose not documented | `/api/profile-picture/6842e6979f0fefa378038b60`, `/api/profile-picture/68421788e15954f670462de5` |

---

### Collection: `profile_pictures`

**Purpose:** Stores user profile pictures as binary data with metadata
**Documents:** 5
**Fields:** 7

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `68432cc58d324ae2a5062669`, `6842e6979f0fefa378038b60` |
| `user_id` | string | 0.0% | Reference to user document ID | `68432c1c46d995c2ca95e661`, `6842e68a30d85de5f6bcbd82` |
| `image_data` | bytes | 0.0% | Field purpose not documented |  |
| `content_type` | string | 0.0% | Field purpose not documented | `image/jpeg` |
| `filename` | string | 0.0% | Field purpose not documented | `profile_68432c1c46d995c2ca95e661_a6e68c1865a5b066.jpg`, `profile_6842e68a30d85de5f6bcbd82_cf269f2c6199c666.jpg` |
| `size` | integer | 0.0% | Field purpose not documented | `104241`, `132164` |
| `created_at` | datetime | 0.0% | Timestamp when document was created | `2025-06-06T18:00:37.524000`, `2025-06-06T13:01:11.403000` |

---

### Collection: `notification_settings`

**Purpose:** Stores user notification preferences and settings
**Documents:** 1
**Fields:** 6

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | string | 0.0% | MongoDB document identifier | `global` |
| `new_workshop_cooldown_hours` | integer | 0.0% | Field purpose not documented | `168` |
| `new_workshop_enabled` | boolean | 0.0% | Field purpose not documented | `True` |
| `reminder_enabled` | boolean | 0.0% | Field purpose not documented | `True` |
| `reminder_hours_before` | integer | 0.0% | Field purpose not documented | `24` |
| `updated_at` | datetime | 0.0% | Timestamp when document was last modified | `2025-06-04T21:26:29.284000` |

---

### Collection: `device_tokens`

**Purpose:** Stores device tokens for push notifications (iOS/Android)
**Documents:** 1
**Fields:** 7

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `68442df72db3a5654dd3b2a2` |
| `user_id` | string | 0.0% | Reference to user document ID | `6841f9c8e15954f670462ddc` |
| `device_token` | string | 0.0% | Push notification device token | `2e3787ba97093d7ffa136af95d6bf535d90fc4d1a3338e80158bda00934e9690` |
| `platform` | string | 0.0% | Device platform (ios/android) | `ios` |
| `created_at` | datetime | 0.0% | Timestamp when document was created | `2025-06-07T12:17:59.748000` |
| `updated_at` | datetime | 0.0% | Timestamp when document was last modified | `2025-06-08T22:30:27.029000` |
| `is_active` | boolean | 0.0% | Boolean flag for active status | `True` |

---

### Collection: `users_deleted`

**Purpose:** Archive of deleted user accounts for audit purposes
**Documents:** 3
**Fields:** 11

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `68410945d2101e575e06631c`, `6841e6f508de78b9f78aff9e` |
| `mobile_number` | string | 0.0% | User's mobile phone number for authentication | `9999999999` |
| `password_hash` | string | 0.0% | Hashed password for secure authentication | `$2b$12$Pt3QtoFi.8kVxd6rfAukqeGjbHLoxx5zvdD2IYBeR2m0bG.NMBps.`, `$2b$12$AoALKKbrTi1I49r7QUca6udAhYRmOnz0Dz6Hhvz53XqLp.PoWJxqS` |
| `name` | string | 0.0% | User's display name | `Integration Test User` |
| `date_of_birth` | string, null | 66.67% | User's birth date | `1998-06-10` |
| `gender` | string | 0.0% | User's gender identity | `other` |
| `profile_complete` | boolean | 0.0% | Boolean flag indicating if user profile is complete | `False` |
| `is_admin` | boolean | 0.0% | Boolean flag for admin privileges | `True`, `False` |
| `created_at` | datetime | 0.0% | Timestamp when document was created | `2025-06-05T03:04:37.535000`, `2025-06-05T18:50:29.353000` |
| `updated_at` | datetime | 0.0% | Timestamp when document was last modified | `2025-06-05T18:49:32.237000`, `2025-06-05T18:50:52.393000` |
| `deleted_at` | datetime | 0.0% | Timestamp when document was soft deleted | `2025-06-05T18:49:32.680000`, `2025-06-05T18:50:52.819000` |

---

### Collection: `reactions`

**Purpose:** Stores user reactions (likes, follows) to artists and content
**Documents:** 42
**Fields:** 8

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `6841e1f108de78b9f78aff9d`, `684427d9c17459f575609da4` |
| `user_id` | string | 0.0% | Reference to user document ID | `68410945d2101e575e06631c`, `6841f9c8e15954f670462ddc` |
| `entity_id` | string | 0.0% | ID of the entity being reacted to | `test_artist_id`, `akshaykundu_akki` |
| `entity_type` | string | 0.0% | Type of entity (ARTIST, STUDIO, etc.) | `ARTIST` |
| `reaction` | string | 0.0% | Type of reaction (LIKE, NOTIFY, etc.) | `LIKE`, `NOTIFY` |
| `created_at` | datetime | 0.0% | Timestamp when document was created | `2025-06-05T18:29:05.643000`, `2025-06-07T11:51:53.926000` |
| `updated_at` | datetime | 0.0% | Timestamp when document was last modified | `2025-06-05T18:29:05.643000`, `2025-06-07T11:51:53.926000` |
| `is_deleted` | boolean | 0.0% | Soft delete flag | `False`, `True` |

---

## Database: `discovery`

### Collection: `workshops_v2`

**Purpose:** Main workshop data including schedules, artists, and booking information
**Documents:** 71
**Fields:** 13

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `6842199adcbaa4181753086d`, `6841fed2c77ae98b67b16955` |
| `payment_link` | string | 0.0% | URL for workshop registration/payment | `https://www.yoactiv.com/event/rajesh-workshop_-21st-june/1071/0`, `https://rzp.io/rzp/jun-harshk` |
| `studio_id` | string | 0.0% | Unique identifier for dance studio | `dance_n_addiction`, `dance.inn.bangalore` |
| `uuid` | string | 0.0% | Field purpose not documented | `dance_n_addiction/rajesh-workshop_-21st-june`, `dance.inn.bangalore/jun-harshk` |
| `event_type` | string | 0.0% | Type of event (workshop, intensive, regulars) | `workshop`, `intensive` |
| `time_details` | array<object> | 0.0% | Array of workshop session times |  |
| `by` | string | 0.0% | Artist name conducting the workshop | `Rajesh Kumar`, `Harsh Kumar` |
| `song` | string, null | 2.82% | Name of the song for the workshop | `Ninnindale`, `Hauli Slowly` |
| `pricing_info` | string | 0.0% | Workshop pricing and payment information | `Single Class:
First 15: 850/-
After that: 950/-
OTS: 1100/-`, `Pre - Registeration :
First 10 Slots : 850/-
Next : 950/-
On The Spot Registeration :
Rs. 1200/- Based on spot availability` |
| `artist_id_list` | array (empty), array<string> | 0.0% | List of artist IDs for multi-artist workshops |  |
| `updated_at` | float | 0.0% | Timestamp when document was last modified | `1749162394.073892`, `1749155530.211481` |
| `version` | integer | 0.0% | Field purpose not documented | `1` |
| `choreo_insta_link` | string, null | 69.01% | Field purpose not documented | `https://www.instagram.com/reel/DKRxauoC_QV/?igsh=eXdvcHc4N3VtYXFp`, `https://www.instagram.com/reel/DIJsJaMydct/?igsh=MWVidmlxMXNtcnRxdA==` |

---

### Collection: `workshop_signatures`

**Purpose:** Unique signatures for workshop deduplication
**Documents:** 0
**Fields:** 0

---

### Collection: `workshops_v2_copy`

**Purpose:** Backup or staging copy of workshop data
**Documents:** 71
**Fields:** 13

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `6842199adcbaa41817530868`, `6842199adcbaa4181753086c` |
| `payment_link` | string | 0.0% | URL for workshop registration/payment | `https://www.yoactiv.com/event/aashsih-lama-workshop_-14th-jun-workshop/1058/0`, `https://www.yoactiv.com/event/raghav_-june-8th-workshop/1055/0` |
| `studio_id` | string | 0.0% | Unique identifier for dance studio | `dance_n_addiction`, `dance.inn.bangalore` |
| `uuid` | string | 0.0% | Field purpose not documented | `dance_n_addiction/aashsih-lama-workshop_-14th-jun-workshop`, `dance_n_addiction/raghav_-june-8th-workshop` |
| `event_type` | string | 0.0% | Type of event (workshop, intensive, regulars) | `workshop`, `intensive` |
| `time_details` | array<object> | 0.0% | Array of workshop session times |  |
| `by` | string | 0.0% | Artist name conducting the workshop | `Aashish Lama`, `Raghav` |
| `song` | string, null | 2.82% | Name of the song for the workshop | `TBD`, `Water (Diljit)` |
| `pricing_info` | string | 0.0% | Workshop pricing and payment information | `Single Class: First 15: 850/-
After that: 950/-
Both Class: 1500/-
OTS: 1100/- (Per session as per availablity)`, `Single Class: First 15: 850/-
Single Class: After that: 950/-
Single Class: OTS: 1100/-
Both Class: 1500/-` |
| `artist_id_list` | array (empty), array<string> | 0.0% | List of artist IDs for multi-artist workshops |  |
| `updated_at` | float, string | 0.0% | Timestamp when document was last modified | `1749162357.924662`, `1749162385.119137` |
| `version` | integer | 0.0% | Field purpose not documented | `1` |
| `choreo_insta_link` | string | 0.0% | Field purpose not documented | `https://www.instagram.com/reel/DKBtBbITYYi/?igsh=Y2w2N2cyY3dna2Ro`, `https://www.instagram.com/reel/DJ4ByA1qk-q/?igsh=bDkxOThsemV4ZjFj` |

---

### Collection: `studios`

**Purpose:** Dance studio information including names, locations, and social links
**Documents:** 4
**Fields:** 5

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `680df1539853ea938f26c54c`, `680df14e9853ea938f26c54a` |
| `studio_id` | string | 0.0% | Unique identifier for dance studio | `dance_n_addiction`, `dance.inn.bangalore` |
| `image_url` | string | 0.0% | URL to profile or promotional image | `https://instagram.fblr1-8.fna.fbcdn.net/v/t51.2885-19/405807979_303617005471969_1594126097266205135_n.jpg?stp=dst-jpg_s320x320_tt6&_nc_ht=instagram.fblr1-8.fna.fbcdn.net&_nc_cat=101&_nc_oc=Q6cZ2QEuwEl0eUvUgOpPcaSrbMMgqEP4X5A7J_8s-fR76zD9mWqlp95nlndisn-3WqWF_6IIJ07CeRFs1JlpmLCqiXvj&_nc_ohc=IeMZguh5OToQ7kNvwEd34iu&_nc_gid=RqghC39JnBJVGG_IVlKkOA&edm=AOQ1c0wBAAAA&ccb=7-5&oh=00_AfMDHitMUiYSAlv_vDhrTp4UYf_0I-uMSC87GaQXNUZVSw&oe=6846A58C&_nc_sid=8b3546`, `https://instagram.fblr1-5.fna.fbcdn.net/v/t51.2885-19/440602058_2822802334542349_4002984582975022806_n.jpg?stp=dst-jpg_s320x320_tt6&_nc_ht=instagram.fblr1-5.fna.fbcdn.net&_nc_cat=1&_nc_oc=Q6cZ2QGwBY6kJTsKRJfEQVmioYBzuawVgaykLvb7vmt4S6NLNZ0cD0UHkRVIOPlME6f0zYuEpXLWNiV6YLLB7VXEKjnZ&_nc_ohc=UTREOu75hrAQ7kNvwG-CkOm&_nc_gid=VQFA_up92v0mSvJWtLW6LQ&edm=AOQ1c0wBAAAA&ccb=7-5&oh=00_AfPD_awn5hZUKeRY6c7zaOuLBQtoDqgURz1yUyOzMYN5_w&oe=68469863&_nc_sid=8b3546` |
| `instagram_link` | string | 0.0% | Instagram profile URL | `https://www.instagram.com/dance_n_addiction/`, `https://www.instagram.com/dance.inn.bangalore/` |
| `studio_name` | string | 0.0% | Display name of the dance studio | `DNA`, `Dance Inn` |

---

### Collection: `users`

**Purpose:** Legacy or test user data in discovery database
**Documents:** 1
**Fields:** 4

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `680f757d05e2b706b5a65943` |
| `username` | string | 0.0% | Field purpose not documented | `admin` |
| `password_hash` | string | 0.0% | Hashed password for secure authentication | `YaB8JepGflVt3rGXU87W+w==$a9YqKUjRmzPYc72LUOBdvw3e3tr6NTm+9NeUBoSLzeU=` |
| `role` | string | 0.0% | Field purpose not documented | `admin` |

---

### Collection: `artists_v2`

**Purpose:** Dance artist profiles with names, images, and social links
**Documents:** 79
**Fields:** 5

#### Fields

| Field | Type(s) | Null % | Description | Sample Values |
|-------|---------|--------|-------------|---------------|
| `_id` | ObjectId | 0.0% | MongoDB document identifier | `680bb8469853ea938f26c537`, `680bb81e9853ea938f26c52a` |
| `artist_id` | string | 0.0% | Unique identifier for artist | `vipuldevrani`, `jordanyashazwi` |
| `artist_name` | string | 0.0% | Display name of the artist | `Vipul Devrani`, `Jordan Yashazwi` |
| `image_url` | string | 0.0% | URL to profile or promotional image | `https://instagram.fblr1-4.fna.fbcdn.net/v/t51.2885-19/476501434_1137606197589296_1907685726104395396_n.jpg?stp=dst-jpg_s320x320_tt6&_nc_ht=instagram.fblr1-4.fna.fbcdn.net&_nc_cat=108&_nc_oc=Q6cZ2QEYOI7YA7oF8i1NBQoXNpu63Yk-r2vuSRig1ZUh-e7yaTJJGfJ8OSN0nouYYqQd_cIYlTPiSQdlJPxim1bwDxWI&_nc_ohc=QIfO8XGa8WYQ7kNvwHSFP96&_nc_gid=8RPWn_mIU409Zx0P2p9q9w&edm=AOQ1c0wBAAAA&ccb=7-5&oh=00_AfPzsgiQJqio6kZeiMbQ_OZEMMbtwSweI-YH5mcxOvFb6A&oe=68469217&_nc_sid=8b3546`, `https://instagram.fblr1-10.fna.fbcdn.net/v/t51.2885-19/402155365_341273691884634_3199070246202347789_n.jpg?stp=dst-jpg_s320x320_tt6&_nc_ht=instagram.fblr1-10.fna.fbcdn.net&_nc_cat=106&_nc_oc=Q6cZ2QE6prQwSn_VudBqCLBSLpqeazEMyiGa-6J-ax62xRS2sR-RjEjeiy71uCpyesTOwDnf_gWo7hTnOH3ZtCsCCoNF&_nc_ohc=RUJZ7u02HlQQ7kNvwGOvaal&_nc_gid=KEeeyRSnhsVJNHUMHV1VeA&edm=AOQ1c0wBAAAA&ccb=7-5&oh=00_AfMt0NW3yTKmmjP0axRsCeYQmA62-E9T28wr2Q3hUtavUg&oe=68468C02&_nc_sid=8b3546` |
| `instagram_link` | string | 0.0% | Instagram profile URL | `https://www.instagram.com/vipuldevrani/`, `https://www.instagram.com/jordanyashazwi/` |

---
