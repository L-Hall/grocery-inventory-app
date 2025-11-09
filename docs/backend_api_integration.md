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
