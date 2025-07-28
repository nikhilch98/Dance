# Gemini Documentation

This document describes the test flows for the Nachna application.

## Streaming API Test Flow

### Test Case: Process Studio

**Purpose:** To test the `/streaming/process-studio` endpoint, which processes a studio's workshops and saves them to the database.

**Endpoint:** `GET /api/streaming/process-studio`

**Request:**

```bash
curl -N -H "Accept: text/event-stream" \
     -H "Cache-Control: no-cache" \
     -X GET \
     "http://localhost:8008/api/streaming/process-studio?studio_id=dance_n_addiction"
```

**Expected Output:**

The API will stream a series of events, including logs and a progress bar. The final event will be a `complete` event.

```json
event: logs
data: {"type":"logs","timestamp":"2025-07-26T20:03:48.499536+05:30","data":{"message":"Starting processing for studio: dance_n_addiction","level":"info"}}

event: logs
data: {"type":"logs","timestamp":"2025-07-26T20:03:48.499539+05:30","data":{"message":"Fetching studio configuration...","level":"info"}}

event: logs
data: {"type":"logs","timestamp":"2025-07-26T20:03:48.499734+05:30","data":{"message":"Connecting to studio website...","level":"info"}}

event: logs
data: {"type":"logs","timestamp":"2025-07-26T20:03:48.499734+05:30","data":{"message":"Scraping workshop links from studio website...","level":"info"}}

event: logs
data: {"type":"logs","timestamp":"2025-07-26T20:03:48.886386+05:30","data":{"message":"Successfully processed all links for studio: dance_n_addiction","level":"success"}}

event: logs
data: {"type":"logs","timestamp":"2025-07-26T20:03:48.886394+05:30","data":{"message":"Found 0 workshops, 0 ignored, 0 old, 0 missing artists","level":"info"}}

event: logs
data: {"type":"logs","timestamp":"2025-07-26T20:03:48.886395+05:30","data":{"message":"No workshops found to process","level":"info"}}

event: logs
data: {"type":"logs","timestamp":"2025-07-26T20:03:48.886396+05:30","data":{"message":"Studio dance_n_addiction processing completed","level":"success"}}

event: progress_bar
data: {"type":"progress_bar","timestamp":"2025-07-26T20:03:48.886397+05:30","data":{"percentage":100,"current":0,"total":0,"message":"Studio processing complete"}}

event: complete
data: {"message":"Process completed"}
```

**Verification:**

To verify that the workshops have been saved to the database, you can connect to the MongoDB instance and query the `workshops_v3` collection in the `discovery` database.

**MongoDB Connection URI:** `mongodb+srv://admin:admin@cluster0.8czn7.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0`

**Example Query (using mongosh):**

```javascript
use discovery;
db.workshops_v3.find({ studio_id: "dance_n_addiction" });
```
