# Fold v2 Test Migration Guide

This guide documents the migration of all tests to v2, including the major architectural changes and how to run the updated tests.

## Overview

Fold v2 introduces significant API changes:
- **Unified Memory Type System** - Replaces 8 discrete types with a unified `Memory` model using `source` field
- **Decay-Weighted Search** - Combines semantic similarity with time-based memory strength
- **Project-Level Decay Configuration** - Configurable strength_weight and decay_half_life_days per project
- **Improved Authentication** - OIDC/OAuth2, API key tokens with hashing, user roles and groups
- **Enhanced Data Models** - New tables for users, groups, API keys, and chunk-based indexing

## PowerShell Test Updates

### Changes Made

#### 1. Memory Type Removal

**Before (v1):**
```powershell
$memBody = @{
    type = "codebase"
    title = "Test"
    content = "..."
} | ConvertTo-Json
```

**After (v2):**
```powershell
$memBody = @{
    title = "Test"
    content = "..."
} | ConvertTo-Json
```

**Reason:** Memory types are no longer part of the API. The server automatically determines `source`:
- If `file_path` is provided → `source = "file"`
- Otherwise → `source = "agent"`

#### 2. Decay Parameters Move to Project Configuration

**Before (v1):**
```powershell
$searchBody = @{
    query = "API authentication"
    strength_weight = 0.3
    decay_half_life_days = 30
} | ConvertTo-Json
```

**After (v2):**
```powershell
# Configure project once
$configBody = @{ strength_weight = 0.3; decay_half_life_days = 30 } | ConvertTo-Json
Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $configBody | Out-Null

# Search uses project config automatically
$searchBody = @{ query = "API authentication" } | ConvertTo-Json
```

**Reason:** Decay parameters are now project-level settings, not per-search parameters. This ensures consistent decay behavior across all searches in a project.

### Updated Test Files

1. **semantic-test.ps1**
   - Removed `type` fields from all memory creations
   - Simplified request bodies (title + content only)

2. **run-tests.ps1**
   - Removed `type` fields from memory creations
   - Removed obsolete `root_path` and `repo_url` fields from project creation

3. **decay-test.ps1**
   - Restructured to set project algorithm config before searching
   - Tests now verify decay effect by changing config and comparing results

4. **unified-decay-test.ps1**
   - Updated to use project config endpoint
   - Simplified search requests (no inline parameters)

### How to Run PowerShell Tests

```powershell
# Start server
cd srv
.\start-server.ps1

# In another terminal
cd test

# Create API token
$token = powershell .\create-token.ps1
$env:FOLD_TOKEN = $token

# Run individual test
.\semantic-test.ps1
.\run-tests.ps1
.\decay-test.ps1
.\algorithm-config-test.ps1

# Or from bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "d:/hh/git/g1/fold/test/semantic-test.ps1"
```

## Rust Integration Tests

### New Test Files

#### 1. `v2_integration_tests.rs`
Contract-based tests validating v2 API structure:
- Project management with decay config
- Memory creation without type field
- Search response structure with decay fields
- User and group management
- API key operations
- Memory source handling (agent, file, git)

Run with:
```bash
cd srv
cargo test --test v2_integration_tests -- --nocapture
```

#### 2. `v2_http_integration_tests.rs`
HTTP-based integration tests making real API calls:
- End-to-end project and memory workflows
- Decay configuration and search behavior
- Error handling and validation
- Requires running Fold server

Run with:
```bash
# Start server first
cd srv
cargo run &

# In another terminal
cd srv
export FOLD_TOKEN=$(cd ../test && powershell .\create-token.ps1)
export FOLD_URL="http://localhost:8765"

# Run with --include-ignored to run marked tests
cargo test --test v2_http_integration_tests -- --nocapture --include-ignored
```

### Updated Existing Tests

**users_groups_apikeys_integration_tests.rs**
- Already covers v2 user, group, and API key features
- Minor updates to align with current database schema
- Tests verify admin-only operations and authorization

## Key v2 API Changes

### Memory Creation

| Field | v1 | v2 | Required |
|-------|----|----|----------|
| `title` | Optional | Optional | No |
| `content` | Required | Required | Yes |
| `type` | Required | Removed | No |
| `author` | Optional | Optional | No |
| `tags` | N/A | Optional | No |
| `file_path` | N/A | Optional | No |
| `metadata` | N/A | Optional | No |

### Memory Source

In v2, `source` replaces the 8-type system:

```
source: "agent" | "file" | "git"
```

**Automatic Assignment:**
- `file_path` provided → `source = "file"`
- Otherwise → `source = "agent"`

### Search Endpoints

| Endpoint | Purpose | Decay Parameters |
|----------|---------|------------------|
| `POST /projects/:id/memories/search` | Memory-specific search | Uses project config |
| `POST /projects/:id/search` | Unified search | Uses project config |

**Note:** Decay parameters (`strength_weight`, `decay_half_life_days`) are no longer sent in search requests. Configure at project level:

```
PUT /projects/:id/config/algorithm
{
  "strength_weight": 0.3,
  "decay_half_life_days": 30.0,
  "ignored_commit_authors": ["ci-bot"]
}
```

### Project Configuration

**New fields:**
- `decay_strength_weight` (0.0-1.0, default 0.3)
- `decay_half_life_days` (≥1.0, default 30.0)
- `ignored_commit_authors` (array of author patterns)

### Response Structure

#### Search Results

**v1:**
```json
{
  "results": [
    {
      "id": "mem-123",
      "title": "...",
      "type": "codebase",
      "score": 0.85
    }
  ]
}
```

**v2:**
```json
{
  "results": [
    {
      "id": "mem-123",
      "title": "...",
      "source": "file",
      "score": 0.85,
      "strength": 0.75,
      "combined_score": 0.79,
      "matched_chunks": [...]
    }
  ]
}
```

**New fields:**
- `source` - Where memory came from (agent/file/git)
- `strength` - Time-decayed memory strength (0.0-1.0)
- `combined_score` - Blended semantic + strength score
- `matched_chunks` - Fine-grained code/text matches with line numbers

### Decay Algorithm

The combined search score is calculated as:

```
combined_score = (1 - strength_weight) × semantic_score + strength_weight × memory_strength

where:
  semantic_score = raw vector similarity (0.0-1.0)
  memory_strength = recency_decay × access_boost
  recency_decay = 2^(-age_days / decay_half_life_days)
  access_boost = log(retrieval_count + 1)
```

**Examples:**
- `strength_weight = 0.0` → Pure semantic search (combined = score)
- `strength_weight = 0.5` → Balanced blend
- `strength_weight = 1.0` → Pure strength search (combined = strength)
- After 30 days with default half-life → strength ≈ 0.5

## Testing Checklist

- [x] PowerShell tests updated for v2 API
  - [x] Removed memory type fields
  - [x] Updated decay configuration pattern
  - [x] Verified endpoint paths

- [x] Rust contract tests created
  - [x] Memory structure validation
  - [x] Response structure validation
  - [x] Decay algorithm validation
  - [x] User/group/API key structures

- [x] Rust HTTP integration tests created
  - [x] Project CRUD operations
  - [x] Decay configuration workflows
  - [x] Memory creation with source detection
  - [x] Search with decay effects
  - [x] Error handling

- [ ] Run full test suite against server
- [ ] Verify all decay calculations match algorithm
- [ ] Test edge cases (very old memories, very new memories)
- [ ] Performance test with large memory sets

## Common Issues and Solutions

### Issue: Memory type field not recognized

**Symptom:** POST to `/projects/:id/memories` with `type` field returns 422 or ignores field

**Solution:** Remove the `type` field from request body. The server determines source automatically.

### Issue: Decay parameters in search request ignored

**Symptom:** Search returns same results regardless of `strength_weight` parameter

**Solution:** Set decay parameters on project via `/projects/:id/config/algorithm` instead of passing in search request.

### Issue: No strength or combined_score in results

**Symptom:** Search results missing decay-related fields

**Solution:** Ensure Fold server v2 is running and properly configured. Check response structure matches v2 format.

### Issue: Search results order changed

**Symptom:** Same query returns different result order than before

**Solution:** This is expected in v2. Results are now ordered by `combined_score` (decay-weighted) instead of raw `score`. Configure `strength_weight = 0.0` for pure semantic ordering.

## Migration Checklist for New Tests

When adding new tests:

1. **Memory Creation Tests**
   - [ ] Remove any `type` field
   - [ ] Test with and without `file_path`
   - [ ] Verify `source` field is set correctly

2. **Search Tests**
   - [ ] Remove decay parameters from request
   - [ ] Configure project decay values before search
   - [ ] Verify response includes `strength` and `combined_score`
   - [ ] Test different `strength_weight` values

3. **Project Tests**
   - [ ] Verify default decay config (0.3, 30.0)
   - [ ] Test algorithm config updates
   - [ ] Validate `strength_weight` range (0.0-1.0)
   - [ ] Validate `decay_half_life_days` range (≥1.0)

4. **Response Validation**
   - [ ] Check `type` field does NOT exist
   - [ ] Verify `source` field is present
   - [ ] Validate decay scoring fields exist
   - [ ] Test `matched_chunks` for fine-grained results

## References

- See `/srv/ARCHITECTURE.md` for v2 architecture details
- See `/test/test-plan.md` for test strategy
- See `/test/setup.md` for environment setup
