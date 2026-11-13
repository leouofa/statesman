# Statesman REST API (`/api/v1`) Specification & Developer Reference

This document provides a comprehensive technical reference for the programmatic REST API exposed by **Statesman** under `/api/v1`. The API is designed for external applications, researchers, and companion client environments (such as a TypeScript Model Context Protocol / MCP server) to query, manipulate, and orchestrate the entire comparative geopolitics catalog, vector embedding manifold, archetype clustering engine, and multi-stage LLM synthesis pipelines.

---

## 1. Architectural Overview & Conventions

### Base URL
```
http://localhost:3000/api/v1
```

### OpenAPI 3.1 Specification
Statesman serves an introspectable OpenAPI 3.1 JSON document directly at:
```http
GET /api/v1/openapi.json
```

### Response Envelopes
All responses are formatted as JSON using a consistent envelope structure:

#### Single Resource or Action Response
```json
{
  "data": { ... },
  "meta": { ... } // optional contextual metadata
}
```

#### Collection Response (with Pagination)
```json
{
  "data": [ ... ],
  "meta": {
    "total": 195,
    "limit": 50,
    "offset": 0
  }
}
```

#### Error Response
Standard HTTP status codes (`400 Bad Request`, `404 Not Found`, `422 Unprocessable Entity`, etc.) return an error object:
```json
{
  "error": {
    "code": "not_found",
    "message": "Couldn't find Country with 'id'=9999",
    "details": ["Optional validation errors or context"]
  }
}
```

### Pagination
Collection endpoints support `limit` (default: `50`, maximum: `500`) and `offset` (default: `0`) query parameters.

### Embedding Vectors (`pgvector` 1024-float arrays)
To keep network payloads lean, endpoints returning `Country` or `City` records include vector metadata (`embedded: boolean`, `embedding_model: string`, `embedded_at: timestamp`, `embedding_dimensions: 1024`), while the raw 1024-float array is omitted by default.
Pass `?include_embedding=true` on any individual or collection query to include the raw vector:
```json
{
  "data": {
    "id": 1,
    "name": "France",
    "embedded": true,
    "embedding_model": "qwen3-embedding:0.6b",
    "embedding": [0.0123, -0.0456, 0.0891, ...]
  }
}
```

### Synchronous vs. Asynchronous Job Execution (`?sync=true`)
Long-running LLM and embedding operations (discovery, population, vector calculation) default to asynchronous execution via ActiveJob/Sidekiq (`202 Accepted` with `{ "data": { "job_id": "...", "status": "queued" } }`).
Clients can:
1. Poll the job status at `GET /api/v1/jobs/:id`.
2. Or pass `?sync=true` on single-entity actions (`POST /api/v1/countries/:id/generate_embedding?sync=true`, `POST /api/v1/continents/:id/populate_countries?sync=true`, `POST /api/v1/countries/:id/populate_cities?sync=true`) to block until execution completes and receive the immediate result (`200 OK`).

---

## 2. API Endpoints by Domain

### 2.1 Platform Status & Introspection

#### `GET /api/v1/status`
Returns overall health, entity counts, embedding coverage stats, and active LLM/embedding configurations.

```bash
curl -s http://localhost:3000/api/v1/status | jq
```
```json
{
  "data": {
    "status": "ok",
    "environment": "development",
    "timestamp": "2026-11-13T02:30:00Z",
    "counts": {
      "continents": 7,
      "countries": 195,
      "countries_embedded": 195,
      "cities": 1560,
      "cities_embedded": 1560,
      "cluster_snapshots": 12,
      "cluster_reports": 8
    },
    "config": {
      "embedding_model": "qwen3-embedding:0.6b",
      "embedding_api_base": "http://localhost:11434/v1",
      "embedding_dimensions": 1024,
      "llm_model": "Qwen3.6-35B-A3B-NVFP4",
      "llm_api_base": "http://localhost:11434/v1",
      "context_window": 262144,
      "digest_char_budget": 576716
    }
  }
}
```

#### `GET /api/v1/openapi.json`
Returns the complete OpenAPI 3.1.0 JSON schema.

---

### 2.2 Global Search

#### `GET /api/v1/search`
Unified semantic or keyword search across both `Country` and `City` entities.

**Query Parameters:**
- `q` (required, string): Search query text.
- `mode` (optional, `semantic` | `keyword` | `auto`, default `auto`): When `semantic`, encodes `q` into a 1024-dim vector using `Llm::EmbeddingGenerator` and runs pgvector cosine distance search.
- `target_type` (optional, `all` | `country` | `city`, default `all`).
- `limit` (optional, integer, default `20`).

```bash
curl -s "http://localhost:3000/api/v1/search?q=maritime+chokepoint+gateway&mode=semantic&limit=5" | jq
```

---

### 2.3 Continents

#### `GET /api/v1/continents`
List continents with optional keyword filter (`?q=`) and country counts.
- `?include_countries=true`: Embeds the list of sovereign states for each continent.
- `?limit=50&offset=0`: Pagination.

#### `GET /api/v1/continents/:id`
Fetch single continent details (includes `countries` by default).

#### `POST /api/v1/continents`
Create a new continent record:
```json
{
  "continent": {
    "name": "Europe",
    "description": "European continent."
  }
}
```

#### `PATCH /api/v1/continents/:id`
Update an existing continent.

#### `DELETE /api/v1/continents/:id`
Delete a continent and its associated countries and cities.

#### `POST /api/v1/continents/upsert_batch`
Batch upsert continent records matching case-insensitively on `name`:
```json
{
  "continents": [
    { "name": "Europe", "description": "European continent with supranational institutions." },
    { "name": "Asia", "description": "Vast landmass spanning major geopolitical power centers." }
  ]
}
```

#### `POST /api/v1/continents/populate`
Triggers `PopulateContinentsJob` via LLM discovery (`?sync=true` supported).

#### `POST /api/v1/continents/:id/populate_countries`
Discovers and populates sovereign states for this specific continent via `PopulateCountriesJob` (`?sync=true` supported).

---

### 2.4 Countries

#### `GET /api/v1/countries`
List and filter countries.
- `?continent_id=1`: Filter by continent ID.
- `?continent=Europe`: Filter by continent name substring.
- `?theme=maritime`: Filter countries containing the thematic tag.
- `?q=france`: Keyword search in name or description.
- `?embedded=true|false`: Filter by vector embedding presence.
- `?include_embedding=true`: Include raw 1024-dim float array.
- `?include_cities=true`: Include associated strategic cities.

#### `GET /api/v1/countries/search`
Semantic or keyword search scoped specifically to countries (`?q=resource+sovereignty&mode=semantic&limit=10`).

#### `GET /api/v1/countries/:id`
Get full country profile including continent and associated cities.

#### `POST /api/v1/countries`
Create a country:
```json
{
  "country": {
    "continent_id": 1,
    "name": "Japan",
    "description": "East Asian island state with high technology and industrial power.",
    "themes": ["island", "tech", "export", "maritime trade"]
  }
}
```

#### `PATCH /api/v1/countries/:id`
Update a country's attributes or themes.

#### `DELETE /api/v1/countries/:id`
Delete a country and its associated cities.

#### `POST /api/v1/countries/upsert_batch`
Batch upsert countries scoped to a continent:
```json
{
  "continent_id": 1,
  "countries": [
    { "name": "France", "description": "Fifth Republic.", "themes": ["republic", "nuclear power"] },
    { "name": "Germany", "description": "Federal Republic.", "themes": ["federal", "industrial"] }
  ]
}
```

#### `GET /api/v1/countries/:id/neighbors`
Find nearest sovereign states in the 1024-dimensional semantic manifold using pgvector cosine distance (`?limit=10&continent_id=optional`).

#### `POST /api/v1/countries/:id/generate_embedding`
Calculate vector embedding for the country (`?sync=true` supported).

#### `POST /api/v1/countries/:id/populate_cities`
Discover and generate 8–10 strategic cities for this country via LLM (`?sync=true` supported).

#### `POST /api/v1/countries/populate`
Trigger bulk LLM discovery across all or a single continent (`?continent_id=1&sync=false`).

---

### 2.5 Cities

#### `GET /api/v1/cities`
List and filter cities.
- `?country_id=5`: Filter by country.
- `?continent_id=1`: Filter by continent.
- `?theme=port`: Filter cities containing the thematic tag.
- `?q=marseille`: Search city name or description.
- `?include_embedding=true`: Include raw vector.

#### `GET /api/v1/cities/search`
Semantic or keyword search scoped to cities (`?q=deepwater+container+port&mode=semantic`).

#### `GET /api/v1/cities/:id`
Get city details, including its structured themes and associated country/continent.

#### `POST /api/v1/cities`
Create a city:
```json
{
  "city": {
    "country_id": 1,
    "name": "Marseille",
    "description": "Major Mediterranean port gateway.",
    "themes": ["deepwater port", "mediterranean gateway", "logistics hub"]
  }
}
```

#### `PATCH /api/v1/cities/:id`
Update city attributes or themes.

#### `DELETE /api/v1/cities/:id`
Delete a city.

#### `GET /api/v1/cities/:id/neighbors`
Find nearest structural city counterparts across world states by cosine distance (`?limit=10`).

#### `POST /api/v1/cities/:id/generate_embedding`
Generate vector embedding for the city (`?sync=true` supported).

#### `POST /api/v1/cities/populate`
Trigger bulk city discovery for all countries or a single country (`?country_id=5`).

---

### 2.6 Live Clustering & Snapshots

#### `GET /api/v1/clusters`
Computes live connected-components vector clusters without modifying the database.
- `target_type`: `Country` (default) or `City`.
- `level`: `1` to `15` (default `5`, $\le 0.16$ to $\le 0.30$ cosine distance).
- `full_coverage`: `true` or `false` (forces 100% catalog assignment / zero singletons).
- `force`: `true` to bypass Rails cache.

Returns discovered multi-member clusters, shared themes, continents, and unclustered singletons.

#### `POST /api/v1/clusters/snapshot` (or `POST /api/v1/cluster_snapshots`)
Computes the clustering and immediately freezes it into an immutable database record:
```json
{
  "target_type": "Country",
  "level": 15,
  "full_coverage": true,
  "title": "Full Catalog Zero-Singleton Snapshot (15)"
}
```

#### `GET /api/v1/cluster_snapshots`
List saved snapshots (`?target_type=Country|City`).

#### `GET /api/v1/cluster_snapshots/:id`
Get snapshot details including all discovered `cluster_groups`, member counts, and generated synthesis reports.
- `?include_groups=true`
- `?include_members=true`
- `?include_reports=true`

#### `DELETE /api/v1/cluster_snapshots/:id`
Delete a snapshot and its cascaded cluster groups and reports.

#### `GET /api/v1/cluster_snapshots/:cluster_snapshot_id/cluster_groups`
List all archetype groups belonging to a snapshot.

#### `GET /api/v1/cluster_groups/:id`
Get a specific cluster group with all member countries or cities.

---

### 2.7 Multi-Stage Synthesis Reports

#### `GET /api/v1/cluster_reports`
List generated scholarly reports (`?cluster_snapshot_id=`, `?target_type=`, `?status=completed`, `?is_detailed=true`).

#### `GET /api/v1/cluster_reports/:id`
Get full report status, progress percentage, markdown content, citations, and sub-reports.
- `?include_summaries=true`: Includes Phase 1 per-cluster analyses.
- `?include_sub_reports=true`: Includes Phase 2 batch narrative analyses.

#### `POST /api/v1/cluster_reports` (or `POST /api/v1/cluster_snapshots/:cluster_snapshot_id/cluster_reports`)
Initiate a 2-Phase Map-Reduce report on a saved snapshot:
```json
{
  "cluster_snapshot_id": 1,
  "prompt": "Analyze cross-continental archetypes of maritime gateway states and naval infrastructure."
}
```

#### `POST /api/v1/cluster_reports/:id/deep_synthesis`
Initiates a 3-Phase Hierarchical Deep Synthesis monograph, reusing Phase 1 summaries from the parent report:
```json
{
  "batch_size": 5
}
```

#### `GET /api/v1/cluster_reports/:cluster_report_id/summaries`
List individual Phase 1 cluster summaries.

#### `GET /api/v1/cluster_report_summaries/:id`
Get a single Phase 1 summary.

#### `GET /api/v1/cluster_reports/:cluster_report_id/sub_reports`
List intermediate Phase 2 batch analyses.

#### `GET /api/v1/cluster_sub_reports/:id`
Get a single Phase 2 batch analysis.

---

### 2.8 Background Jobs

#### `GET /api/v1/jobs`
List recently tracked asynchronous operations (`?limit=20`).

#### `GET /api/v1/jobs/:id`
Poll the execution state, progress, and result of an ActiveJob/Sidekiq background task:
```bash
curl -s http://localhost:3000/api/v1/jobs/21b96495-231a-4299-8dcf-f2771d9d7b88 | jq
```
```json
{
  "data": {
    "job_id": "21b96495-231a-4299-8dcf-f2771d9d7b88",
    "job_class": "PopulateCountriesJob",
    "status": "running",
    "message": "Discovering countries for Europe (1/7)...",
    "progress": { "current": 1, "total": 7, "continent": "Europe" },
    "enqueued_at": "2026-11-13T02:31:00Z",
    "started_at": "2026-11-13T02:31:01Z",
    "completed_at": null
  }
}
```

---

### 2.9 Settings

#### `GET /api/v1/settings`
Returns embedding completion stats for Countries and Cities, model parameters, and context window presets.

#### `PATCH /api/v1/settings/context_window`
Dynamically update the active LLM context window:
```json
{
  "context_window": 131072
}
```

#### `POST /api/v1/settings/generate_embeddings`
Enqueue bulk embedding generation:
```json
{
  "model_type": "Country",
  "only_missing": true
}
```

---

## 3. TypeScript MCP Client Integration Example

Below is a minimal Node/TypeScript snippet demonstrating how an MCP server or client tool can interact with Statesman:

```typescript
import axios from "axios";

const client = axios.create({
  baseURL: "http://localhost:3000/api/v1",
  timeout: 60000
});

// Tool: Search cross-continental countries or cities
export async function searchStatesman(query: string, mode: "semantic" | "keyword" = "semantic") {
  const res = await client.get("/search", { params: { q: query, mode, limit: 10 } });
  return res.data.data;
}

// Tool: Find nearest counterpart states to a known country
export async function getCounterparts(countryId: number, limit = 5) {
  const res = await client.get(`/countries/${countryId}/neighbors`, { params: { limit } });
  return res.data.data;
}

// Tool: Run live clustering on cities and freeze snapshot
export async function createFullCoverageSnapshot(title: string) {
  const res = await client.post("/clusters/snapshot", {
    target_type: "City",
    level: 15,
    full_coverage: true,
    title
  });
  return res.data.data;
}
```
