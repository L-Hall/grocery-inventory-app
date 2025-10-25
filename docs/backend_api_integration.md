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
