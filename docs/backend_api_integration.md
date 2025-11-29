# Backend Integration Contracts

Updated backend endpoints replacing the preview repository shims. These routes are available once `kUsePreviewMode` is `false` and the Firebase Function API is deployed.

## Parsing Endpoints

### `POST /inventory/parse/text`
- **Purpose:** Convert free-form grocery text into structured updates.
- **Request body:**
  ```json
  {
    "text": "bought 2 litres of milk and a pack of strawberries"
  }
  ```
- **Response (200):**
  ```json
  {
    "success": true,
    "updates": [
      {
        "name": "Milk",
        "quantity": 2,
        "unit": "litre",
        "action": "add",
        "category": "dairy",
        "location": "fridge",
        "confidence": 0.91,
        "expirationDate": "2024-05-12T00:00:00.000Z"
      }
    ],
    "confidence": 0.88,
    "warnings": "Review recommended before applying updates.",
    "usedFallback": false,
    "originalText": "bought 2 litres of milk and a pack of strawberries",
    "needsReview": false,
    "message": "Text parsed successfully with high confidence."
  }
  ```

### `POST /inventory/parse/image`
- **Purpose:** Parse a receipt or grocery-list photo (base64).
- **Request body:**
  ```json
  {
    "image": "<base64-encoded image>",
    "imageType": "receipt" // or "list"
  }
  ```
- **Response:** Same schema as `parse/text`.

### `POST /inventory/parse`
- Backwards compatible combined endpoint. Accepts either `text` or `image`, and is now a thin wrapper around the dedicated routes.

## Upload Ingestion Endpoints

Async parsing for large PDFs or high-resolution receipts occurs through a small upload pipeline:

### `POST /uploads`
- **Purpose:** Reserve Storage space and get a signed URL for direct uploads.
- **Request body:**
  ```json
  {
    "filename": "receipt.pdf",
    "contentType": "application/pdf",
    "sizeBytes": 1048576,
    "sourceType": "pdf" // optional: pdf, text, receipt, list
  }
  ```
- **Response (200):**
  ```json
  {
    "success": true,
    "uploadId": "9b4a4d50-8e35-4f6e-9dbf-1a4d560ab1d8",
    "storagePath": "uploads/USER_ID/UPLOAD_ID/receipt.pdf",
    "bucket": "grocery-app.appspot.com",
    "uploadUrl": "https://storage.googleapis.com/...",
    "uploadUrlExpiresAt": "2024-06-01T12:34:56.000Z",
    "status": "awaiting_upload"
  }
  ```

### `GET /uploads/{uploadId}`
- **Purpose:** Retrieve metadata + current processing status for a specific upload.
- **Response (200):**
  ```json
  {
    "success": true,
    "upload": {
      "id": "UPLOAD_ID",
      "filename": "receipt.pdf",
      "storagePath": "uploads/USER_ID/UPLOAD_ID/receipt.pdf",
      "bucket": "grocery-app.appspot.com",
      "contentType": "application/pdf",
      "status": "queued",
      "processingStage": "queued",
      "processingJobId": "job_abc123",
      "createdAt": "...",
      "updatedAt": "..."
    }
  }
  ```

### `POST /uploads/{uploadId}/queue`
- **Purpose:** Flag that the file is present in Storage and enqueue it for AI parsing.
- **Response (200):**
  ```json
  {
    "success": true,
    "jobId": "job_abc123",
    "status": "queued"
  }
  ```

Creating a job adds a document to the global `upload_jobs` collection. A Firestore-triggered worker updates the job to `awaiting_parser` and marks the user upload document as `processing`, ready for the agent pipeline to take over.

### `POST /inventory/ingest`
- **Purpose:** Create an ingestion job that runs the AI agent asynchronously (no blocking wait). Accepts either raw text or an `uploadId` that will be wired up later.
- **Request body:**
  ```json
  {
    "text": "used 2 eggs and bought 3 yogurts",
    "metadata": {
      "source": "manual-entry"
    }
  }
  ```
- **Response (200):**
  ```json
  {
    "success": true,
    "jobId": "f53f7f0f-6a6e-437d-98ab-d2e9761b3180",
    "status": "pending",
    "jobPath": "users/UID/ingestion_jobs/f53f7f0f-6a6e-437d-98ab-d2e9761b3180"
  }
  ```
- The client should watch `users/{uid}/ingestion_jobs/{jobId}` (or poll) until `status` is `completed` or `failed`. On completion the document contains `agentResponse` and `resultSummary`; on failure `lastError` is populated.
- When an `/uploads/{uploadId}/queue` job is created, the backend now downloads the uploaded blob, extracts text (plain text directly, PDFs via a lightweight text extractor, receipts/photos via the OpenAI Vision parser), and immediately writes an ingestion job that references the upload metadata. The original upload document records the `ingestionJobId` plus a `textPreview` so the UI can link the background process to the originating file.

### Agent Metrics Stream
- Every agent interaction (including ingestion jobs) now writes to `agent_interactions/`.
- A metrics trigger aggregates these events into:
  - `agent_metrics/global` – lifetime totals.
  - `agent_metrics/daily/{YYYY-MM-DD}` – per-day snapshots.
- Each doc tracks totals, success count, fallback count, latency sums, confidence sums, and bucketed histograms:
  - `latencyBuckets.lt_2s`, `latencyBuckets.2s_5s`, `latencyBuckets.gt_5s`.
  - `confidenceBuckets.low` (<0.5), `confidenceBuckets.medium` (0.5–0.8), `confidenceBuckets.high` (>0.8).
- Dashboards can bind directly to these docs (or export to BigQuery) to monitor latency, fallback rate, and confidence distribution over time.

## Apply Endpoint

### `POST /inventory/apply`
- **Purpose:** Apply the parsed updates to Firestore with validation feedback.
- **Request body:**
  ```json
  {
    "updates": [
      {
        "name": "Milk",
        "quantity": 2,
        "unit": "litre",
        "action": "add",
        "category": "dairy",
        "location": "fridge",
        "expirationDate": "2024-05-12T00:00:00.000Z",
        "notes": "Organic"
      }
    ]
  }
  ```
- **Response (200):**
  ```json
  {
    "success": true,
    "results": [
      {
        "id": "abc123",
        "name": "Milk",
        "success": true,
        "action": "updated",
        "quantity": 5,
        "expirationDate": "2024-05-12T00:00:00.000Z",
        "message": "Added Milk: now 5 litre"
      }
    ],
    "summary": {
      "total": 1,
      "successful": 1,
      "failed": 0
    },
    "validationErrors": []
  }
  ```
- Partial failures return `success: false` with `validationErrors` populated and per-item failures in `results`. The HTTP status remains 200 so the client can display individual errors.

## Parsed Item Contract

Every parsed update shares a common shape:

| Field            | Type      | Notes                                                                 |
|------------------|-----------|-----------------------------------------------------------------------|
| `name`           | string    | Normalised item name (title case).                                    |
| `quantity`       | number    | Non-negative quantity (float).                                        |
| `unit`           | string    | Canonical unit (`litre`, `kg`, `pack`, etc.).                          |
| `action`         | enum      | `add`, `subtract`, or `set`.                                          |
| `category`       | string?   | Optional grocery category.                                            |
| `location`       | string?   | Optional storage hint (fridge/pantry/freezer/etc.).                   |
| `notes`          | string?   | Additional context from the source text or receipt.                   |
| `confidence`     | number    | 0–1 confidence score from the parser.                                 |
| `expirationDate` | string?   | ISO 8601 expiry/best-before date. Alias `expiryDate` also accepted.   |
| `brand`          | string?   | Optional brand or variety.                                            |

The mobile client stores edited items with the same schema and forwards them to `/inventory/apply`. Backend validation clamps quantities to non-negative numbers and normalises `expirationDate` to ISO strings before persisting.

## Locations API

- `GET /locations` – returns the user-defined location catalogue used by filters and inventory forms.
- `PUT /locations/{locationId}` – create/update a location. Payload accepts `name`, `color` (hex), `icon` (Material icon name), `temperature`, and optional `sortOrder`.
- `DELETE /locations/{locationId}` – remove a stored location definition.

## User Preferences API

- `GET /user/preferences` – bundles settings, saved searches, and custom views into a single payload.
- `PUT /user/preferences/settings` – updates preference fields (`defaultView`, `searchHistory`, `exportPreferences`, `bulkOperationHistory`).
- `PUT /user/preferences/saved-searches/{searchId}` – upserts a saved search by ID (payload: `name`, `config`, optional search helpers such as `searchFields`).
- `DELETE /user/preferences/saved-searches/{searchId}` – removes a saved search.
- `PUT /user/preferences/custom-views/{viewId}` – upserts a custom inventory view definition.
- `DELETE /user/preferences/custom-views/{viewId}` – deletes a custom view.

## Maintenance Scripts

To keep legacy data aligned with the stricter validation rules, run the helper scripts in `scripts/` against production (or the emulator) as needed:

- `backfill-inventory-metadata.js` — ensures every inventory document has `updatedAt`, regenerated `searchKeywords`, and sane defaults for `unit`, `category`, and `lowStockThreshold`.
- `backfill-search-keywords.js` — older script that only regenerates the `searchKeywords` field; superseded by the metadata backfill but retained for quick keyword-only runs.

Example:

```bash
FIREBASE_CREDENTIALS_PATH=/path/to/serviceAccount.json \
node scripts/backfill-inventory-metadata.js
```

The script will iterate each user’s inventory collection, batching updates in groups of 400 writes and reporting counts per user.

## Agent Endpoints

### `POST /agent/ingest`
- **Purpose:** Send free-form grocery text through the OpenAI Agent runner so it can parse and immediately apply updates using the same validation logic as `/inventory/apply`.
- **Request body:**
  ```json
  {
    "text": "Bought 2 gallons of milk and used 3 eggs",
    "metadata": {
      "source": "upload:receipt_123"
    }
  }
  ```
- **Response (200):**
  ```json
  {
    "success": true,
    "response": "Applied 2 updates. Milk increased to 5 gallons; Eggs decreased to 9 count."
  }
  ```
- On failure the route returns `{ success: false, error: "..." }` with an HTTP 500 status so clients can fall back to manual review.
