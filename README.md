# Dance Workshop Application – Project Documentation

## Overview

This project is a **full-stack web application** for managing and discovering dance workshops, artists, and studios, primarily in Bangalore. It features:

- **REST API** (FastAPI) for CRUD operations and workshop discovery.
- **Admin Panel** for managing studios, artists, and workshops.
- **Automated Data Population Scripts** for scraping, processing, and updating workshop and artist data.
- **Modern Frontend** (Jinja2 + HTML/CSS/JS) for browsing and filtering workshops.
- **MongoDB** as the backend database.

---

## Features

### 1. Workshop Discovery
- **Browse all workshops**: View, filter, and sort all available dance workshops.
- **Browse by artist or studio**: Filter workshops by specific artists or studios.
- **Workshop details**: Each workshop includes date, time, instructor, song, pricing, and registration link.

### 2. Artist & Studio Profiles
- **Artist listing**: View all artists with active workshops, including their Instagram and profile picture.
- **Studio listing**: View all studios, with Instagram and profile picture.

### 3. Admin Panel
- **Authentication**: Secure login for admin users.
- **CRUD operations**: Create, read, update, and delete studios, artists, and workshops via REST API endpoints.
- **Session/token-based authentication** for admin API.

### 4. Data Automation
- **Workshop population**: Scripts to scrape, analyze, and populate workshop data from studio websites.
- **Artist population**: Scripts to fetch and update artist data (including profile pictures) from Instagram.
- **Studio population**: Scripts to fetch and update studio data (including profile pictures) from Instagram.

### 5. Utilities
- **Screenshot capture**: Automated screenshots of workshop pages for AI analysis.
- **Date/time formatting**: Consistent formatting and parsing of workshop times.
- **Caching**: In-memory caching for API responses to improve performance.

---

## File Structure

```
Dance/
│
├── server.py                # Main FastAPI server (API, web routes, admin, CRUD)
├── config.py                # Environment and configuration management
├── requirements.txt         # Python dependencies
├── README.md                # Project overview and setup instructions
│
├── scripts/
│   ├── populate_workshops.py  # Script to scrape and populate workshop data
│   ├── populate_artists.py    # Script to fetch/update artist data from Instagram
│   ├── populate_studios.py    # Script to fetch/update studio data from Instagram
│   └── test_script.py         # Miscellaneous/test utilities
│
├── studios/                 # Studio-specific scraping logic (not fully shown)
│
├── utils/
│   └── utils.py             # Utility functions (DB, date/time, screenshots, etc.)
│
├── templates/
│   └── website/
│       ├── index.html           # Home page
│       ├── all_workshops.html   # All workshops listing (modern UI)
│       ├── browse_by_artists.html
│       ├── browse_by_studios.html
│       └── admin_panel.html     # Admin panel UI
│
├── static/
│   └── assets/              # Static assets (images, etc.)
│
└── venv/                    # Python virtual environment (not tracked)
```

---

## File-by-File Documentation

### `server.py` (Main FastAPI Server)

- **Purpose**: Hosts the REST API, web routes, and admin endpoints.
- **Key Sections**:
  - **API Models**: Pydantic models for workshops, artists, studios, and sessions.
  - **DatabaseOperations**: Static methods for fetching and processing data from MongoDB.
  - **Web Routes**: Serve HTML pages for browsing workshops, artists, and studios.
  - **API Routes**: Endpoints for fetching workshops, artists, studios, and sessions.
  - **Admin Authentication**: Secure login, token management, and protected admin API.
  - **CRUD Endpoints**: Full CRUD for studios, artists, and workshops (admin only).
  - **Image Proxy**: Endpoint to proxy images and bypass CORS.
  - **Utilities**: Password hashing, token verification, etc.

**Code Comments**:  
- Each function and class is documented with docstrings.
- CRUD endpoints are grouped and commented.
- Security and authentication helpers are explained.
- Database access patterns are described.

---

### `config.py` (Configuration Management)

- **Purpose**: Manages environment-specific settings (dev/prod), MongoDB URIs, and OpenAI API keys.
- **Key Features**:
  - `Config` class: Loads settings based on environment.
  - `parse_args`: Command-line argument parsing for scripts.
  - Defaults to development environment if not specified.

**Code Comments**:  
- Each class and function is documented.
- Environment selection logic is explained.

---

### `utils/utils.py` (Utility Functions)

- **Purpose**: Provides reusable utilities for DB access, date/time formatting, screenshot capture, URL handling, and caching.
- **Key Features**:
  - **DatabaseManager**: Connects to MongoDB using config.
  - **DateTimeFormatter**: Formats dates/times for display and storage.
  - **ScreenshotManager**: Captures and uploads screenshots using Selenium and MagicAPI.
  - **URLManager**: Fetches and parses URLs, extracts links.
  - **Caching**: Decorator for caching API responses.
  - **Retry**: Decorator for retrying failed operations.
  - **Image Utilities**: Checks if an image URL is downloadable.

**Code Comments**:  
- Each class and method is documented with clear explanations.
- Decorators and utility functions have usage notes.

---

### `scripts/populate_workshops.py` (Workshop Data Population)

- **Purpose**: Scrapes, analyzes, and populates workshop data from studio websites.
- **Key Features**:
  - **WorkshopProcessor**: Handles screenshot capture, AI analysis (OpenAI GPT), and data formatting.
  - **StudioProcessor**: Processes all workshops for a studio, bulk updates MongoDB.
  - **Parallel Processing**: Uses ThreadPoolExecutor for concurrent studio processing.
  - **Artist Data**: Fetches artist info for AI context.
  - **Command-line Arguments**: Select environment and studio.

**Code Comments**:  
- Each class and method is documented.
- AI prompt structure and logic are explained.
- Error handling and cleanup are described.

---

### `scripts/populate_artists.py` (Artist Data Population)

- **Purpose**: Fetches and updates artist data (including profile pictures) from Instagram.
- **Key Features**:
  - **ArtistManager**: Handles DB updates and image checks.
  - **InstagramAPI**: Fetches HD profile pictures using Instagram's private API.
  - **Artist List**: Hardcoded list of artists to process.
  - **Rate Limiting**: Sleeps between requests to avoid rate limits.

**Code Comments**:  
- Each class and function is documented.
- API interaction and error handling are explained.

---

### `scripts/populate_studios.py` (Studio Data Population)

- **Purpose**: Fetches and updates studio data (including profile pictures) from Instagram.
- **Key Features**:
  - **StudioManager**: Handles DB updates and image checks.
  - **InstagramAPI**: Fetches HD profile pictures.
  - **Studio List**: Hardcoded list of studios to process.

**Code Comments**:  
- Each class and function is documented.
- API interaction and error handling are explained.

---

### `templates/website/all_workshops.html` (Frontend UI)

- **Purpose**: Modern, responsive UI for browsing, filtering, and sorting all workshops.
- **Key Features**:
  - **Table View**: Lists all workshop sessions with date, time, instructor, song, pricing, studio, and registration link.
  - **Sorting & Filtering**: By date, instructor, song, and studio.
  - **Search**: Live search by instructor, song, or studio.
  - **Responsive Design**: Mobile-friendly layout.
  - **Accessibility**: ARIA labels and keyboard navigation.

**Code Comments**:  
- Inline comments in HTML and JS for UI logic.
- CSS variables and responsive breakpoints are explained.

---

### `requirements.txt`

- **Purpose**: Lists all Python dependencies for the project.
- **Key Packages**: `fastapi`, `uvicorn`, `pymongo`, `openai`, `selenium`, `jinja2`, `beautifulsoup4`, etc.

---

## Data Model Overview

- **Studios**:  
  - `studio_id`, `studio_name`, `image_url`, `instagram_link`
- **Artists**:  
  - `artist_id`, `artist_name`, `image_url`, `instagram_link`
- **Workshops**:  
  - `uuid`, `payment_link`, `studio_id`, `studio_name`, `updated_at`, `workshop_details`
  - `workshop_details`: List of sessions, each with `time_details`, `by`, `song`, `pricing_info`, `timestamp_epoch`, `artist_id`, `date`, `time`

---

## How to Extend or Use This Project

- **To add a new studio**:  
  - Add scraping logic in `studios/`, update `scripts/populate_workshops.py` and `scripts/populate_studios.py`.
- **To add a new artist**:  
  - Add to the list in `scripts/populate_artists.py`.
- **To add new features to the admin panel**:  
  - Update `server.py` (CRUD endpoints) and `templates/website/admin_panel.html`.
- **To change database or environment**:  
  - Update `config.py` or use command-line flags in scripts.
- **To update the frontend**:  
  - Edit templates in `templates/website/` and static assets in `static/`.

---

## Security Notes

- **Admin authentication** uses secure password hashing and token-based auth.
- **Tokens** are stored in memory for demo; use Redis or DB for production.
- **CORS** is enabled for all origins in development; restrict in production.

---

## Onboarding for AI Models

- **All data access** is via MongoDB, using the structure above.
- **Workshop data** is processed using OpenAI GPT for extraction from screenshots.
- **All endpoints** are documented with docstrings and type hints.
- **Scripts** are modular and can be run independently for data population.
- **Frontend** is decoupled from backend, using REST API for data.

---

## Next Steps

- Add more tests and validation for data integrity.
- Improve error handling and logging.
- Add user authentication for workshop registration (if needed).
- Expand frontend with more features (calendar view, artist/studio profiles, etc.).

---

# Code Comments

**All main files are already well-documented with docstrings and inline comments.**  
If you want even more granular inline comments in the code, let me know which files or sections you want to focus on, and I can add them line-by-line.

---

**This documentation is ready to be used in Cursor or any other onboarding context.**  
Let me know if you want more detailed code comments for any specific file or section!
