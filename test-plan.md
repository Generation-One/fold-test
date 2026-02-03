# Fold Test Plan

## Overview

This folder contains test files and scripts to verify Fold's core functionality:
- API endpoints
- Database operations
- **Semantic vector search** with Qdrant embeddings
- **Memory decay** (ACT-R inspired recency bias)
- Embedding generation (Gemini 768-dimensional)
- Project configuration
- Git workflow (commits & PRs)
- **Webhook loop prevention** (bot author filtering)

## Prerequisites

1. **Fold server running** on `http://localhost:8765`
2. **Qdrant** running on `http://localhost:6334`
3. **Gemini API key** in `srv/.env` as `GOOGLE_API_KEY`
4. **API token** created via `create-token.ps1`

See [setup.md](setup.md) for detailed setup instructions.

## Test Categories

### 1. Health & Connectivity (Automated)
- [x] Server health endpoint responds
- [x] Qdrant connection works
- [x] Database is accessible

### 2. Project Management (Automated)
- [x] Create project
- [x] List projects
- [x] Get project by ID
- [x] Delete project

### 3. Memory Operations (Automated)
- [x] Add memory (general type)
- [x] List memories
- [x] Search memories (semantic)

### 4. Embedding Provider (Automated)
- [x] Gemini provider healthy
- [x] Embeddings status check

### 5. Semantic Search with Rich Content (Automated)
- [x] Add codebase memory
- [x] Add decision memory
- [x] Search finds auth content
- [x] Search finds data processing content

### 6. Project Configuration (Automated)
- [x] Create project with full config (root_path, repo_url)
- [x] Update project settings (PUT)

### 7. Git Sync (Manual - if configured)
- [ ] Webhook receives push events
- [ ] Files are indexed on push
- [ ] Commit summaries generated

### 8. Git Workflow (Manual)
- [x] Create commit with proper format
- [x] Commit message follows conventions
- [x] Co-Author line included
- [x] Create PR with summary and test plan
- [x] PR description is well-formatted
- [x] Changes pushed to remote branch

**Verified:** PR #1 created at https://github.com/Generation-One/fold-test/pull/1

## Running Tests

### Quick Run (16 automated tests)

```powershell
cd test
.\run-tests.ps1 -Token "fold_your-token-here"
```

### Expected Output

```
========================================
  FOLD TEST SUITE
  Server: http://localhost:8765
========================================

1. Health & Connectivity
  Server health... PASS
  Qdrant connection... PASS

2. Project Management
  Create project... PASS
  List projects... PASS
  Get project... PASS
  Delete project... PASS

3. Memory Operations
  Add memory... PASS
  List memories... PASS
  Search memories... PASS

4. Embedding Provider
  Embeddings healthy... PASS

5. Semantic Search with Rich Content
  Add codebase memory... PASS
  Add decision memory... PASS
  Waiting for embeddings...
  Search finds auth content... PASS
  Search finds data processing content... PASS

6. Project Configuration
  Project created with config... PASS
  Update project settings... PASS

========================================
  RESULTS
========================================
  Passed:  16
  Failed:  0
  Skipped: 0
```

## Test Scripts

| Script | Purpose |
|--------|---------|
| `run-tests.ps1` | Main test runner (16 tests) |
| `semantic-test.ps1` | Semantic search verification (7 tests) |
| `decay-test.ps1` | Memory decay/recency bias tests (5 tests) |
| `unified-decay-test.ps1` | Unified search endpoint decay tests (3 tests) |
| `algorithm-config-test.ps1` | Algorithm configuration endpoint tests (6 tests) |
| `create-token.ps1` | Generate API token for testing |

### Semantic Search Test

Verifies that search returns semantically related results even when query uses different words:

```powershell
.\semantic-test.ps1 -Token "fold_your-token"
```

Tests queries like "how do users authenticate" correctly match memories about "JWT tokens and bcrypt hashes".

### Decay Test

Verifies ACT-R inspired memory decay:

```powershell
.\decay-test.ps1 -Token "fold_your-token"
```

Tests:
- Pure semantic search (strength_weight=0)
- Balanced blend (strength_weight=0.3, default)
- Pure strength-based (strength_weight=1.0)
- Different half-life values (1 day, 30 days, 365 days)

## Test Data

Sample files in `sample-files/` for manual indexing tests:
- `sample.ts` - TypeScript authentication module
- `sample.py` - Python data processor
- `sample.md` - Markdown documentation

## Environment

| Variable | Description | Default |
|----------|-------------|---------|
| `FOLD_URL` | Server URL | `http://localhost:8765` |
| `FOLD_TOKEN` | API token | Required |

## API Endpoints Tested

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server health |
| GET | `/health/ready` | Readiness with component checks |
| POST | `/projects` | Create project |
| GET | `/projects` | List projects |
| GET | `/projects/:id` | Get project |
| PUT | `/projects/:id` | Update project |
| GET | `/projects/:id/config/algorithm` | Get algorithm config |
| PUT | `/projects/:id/config/algorithm` | Update algorithm config |
| DELETE | `/projects/:id` | Delete project |
| POST | `/projects/:id/memories` | Add memory |
| GET | `/projects/:id/memories` | List memories |
| POST | `/projects/:id/search` | Semantic search |

## Memory Types

Valid memory types for the API:
- `codebase` - Code documentation
- `session` - Session summaries
- `spec` - Feature specifications
- `decision` - Architectural decisions
- `task` - Task tracking
- `general` - General notes

## Memory Decay Parameters

Search endpoints accept decay parameters to control recency bias:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strength_weight` | float | 0.3 | Blend weight: 0.0 = pure semantic, 1.0 = pure strength |
| `decay_half_life_days` | float | 30 | Half-life for exponential decay |

### How Decay Works

1. **Fresh memories** have strength ~1.0
2. **After half-life** (30 days by default), strength ~0.5
3. **Access frequency** boosts strength via `log2(1 + retrieval_count) * 0.1`
4. **Combined score** = `(1 - weight) * semantic_score + weight * strength`

Example: A 30-day-old memory with score 0.9 and strength 0.5:
- Default (weight=0.3): combined = 0.7 * 0.9 + 0.3 * 0.5 = 0.78
- Pure semantic (weight=0): combined = 0.9
- Pure strength (weight=1): combined = 0.5

## Algorithm Configuration

Projects can have custom decay algorithm settings via the `/projects/:id/config/algorithm` endpoint.

### Configurable Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strength_weight` | float | 0.3 | Blend weight: 0.0 = pure semantic, 1.0 = pure strength |
| `decay_half_life_days` | float | 30 | Half-life for exponential decay |
| `ignored_commit_authors` | array | [] | Author patterns to ignore during webhook processing |

### Example: Configure a project

```powershell
$body = @{
    strength_weight = 0.5
    decay_half_life_days = 7
    ignored_commit_authors = @("my-ci-bot", "deploy-bot")
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8765/projects/my-project/config/algorithm" `
    -Method PUT -Headers $headers -Body $body
```

### Example: Get current configuration

```powershell
Invoke-RestMethod -Uri "http://localhost:8765/projects/my-project/config/algorithm" `
    -Method GET -Headers $headers
```

## Webhook Loop Prevention

When Fold syncs metadata to git repos, it could trigger webhooks that re-index the same content. This is prevented by:

1. **Bot author filtering**: Commits from these authors are automatically skipped:
   - Authors containing "fold"
   - Authors containing "[bot]"
   - Authors containing "github-actions"
   - Authors containing "dependabot"
   - Authors containing "noreply@"

2. **SHA deduplication**: Commits already processed (by SHA) are skipped

## Troubleshooting

See [setup.md](setup.md#troubleshooting) for common issues and solutions.
