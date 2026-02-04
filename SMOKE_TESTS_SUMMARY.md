# Fold v2 Smoke Tests - Complete Summary

## Overview

Complete PowerShell smoke test suite for validating all Fold v2 features:
- Project and decay configuration
- Memory operations (create, search)
- Decay-weighted search scoring
- File chunking and database verification
- API endpoint validation
- Error handling

## Test Files Created

### 1. `v2-comprehensive-smoke-test.ps1` - FULL SUITE
Complete end-to-end smoke test covering ALL v2 features.

**Run:**
```powershell
cd test
$env:FOLD_TOKEN = (powershell .\create-token.ps1)
.\v2-comprehensive-smoke-test.ps1
```

**Tests:** 30+ test cases organized in 7 categories

**Categories:**

#### 1. PROJECT MANAGEMENT (4 tests)
- Create project with defaults
- Verify default decay config (strength_weight=0.3, decay_half_life_days=30)
- Update decay configuration
- List projects

#### 2. MEMORY OPERATIONS (4 tests)
- Create memory without type field
- Verify source set to "agent"
- Create memory with file_path (source="file")
- List memories

#### 3. SEMANTIC SEARCH (4 tests)
- Search with decay config
- Search includes decay fields (score, strength, combined_score)
- Change strength_weight=0 (pure semantic)
- Change strength_weight=1.0 (pure strength)

#### 4. CHUNK DATABASE VERIFICATION (5 tests)
- Database connected
- Chunks table exists
- File memory created chunks
- Chunks have valid line numbers
- Chunks have content_hash

#### 5. API ENDPOINT VALIDATION (8 tests)
- GET /health
- GET /projects (list)
- GET /projects/:id
- POST /projects/:id/memories (create)
- GET /projects/:id/memories (list)
- POST /projects/:id/search (search)
- GET /projects/:id/config/algorithm
- PUT /projects/:id/config/algorithm

#### 6. ERROR HANDLING (2 tests)
- Reject invalid strength_weight (>1.0)
- Reject empty memory content

#### 7. CLEANUP (1 test)
- Delete project

### 2. `chunk-db-smoke-test.ps1` - CHUNK-FOCUSED
Specialized test focusing on file chunking and database verification.

**Run:**
```powershell
cd test
$env:FOLD_TOKEN = (powershell .\create-token.ps1)
.\chunk-db-smoke-test.ps1
```

**Tests:** 8 test cases focused on chunks

**Tests:**
1. Rust file chunks created
2. Chunk metadata validation (node_type, node_name, start/end lines)
3. Node type validation
4. TypeScript file chunks created
5. Content hash verification
6. Total chunk count
7. Language detection
8. Line number ranges and statistics

## Expected Output

### Success Output
```
========================================
  FOLD V2 COMPREHENSIVE SMOKE TEST SUITE
========================================

1. PROJECT MANAGEMENT
  Create project with defaults... PASS
  Verify default decay config... PASS
  Update decay config... PASS
  List projects... PASS

2. MEMORY OPERATIONS
  Create memory without type field... PASS
  Verify source set to agent... PASS
  Create memory with file_path... PASS
  List memories... PASS

3. SEMANTIC SEARCH
  Search with decay config... PASS
  Search includes decay fields... PASS
  Change strength_weight to 0... PASS
  Change strength_weight to 1.0... PASS

4. CHUNK DATABASE VERIFICATION
  Database connected... PASS
  Chunks table exists... PASS
  File memory created chunks... PASS
  Chunks have valid line numbers... PASS
  Chunks have content_hash... PASS

5. API ENDPOINT VALIDATION
  GET /health... PASS
  GET /projects... PASS
  ...

6. ERROR HANDLING
  Reject invalid strength_weight... PASS
  Reject empty memory content... PASS

7. CLEANUP
  Delete project... PASS

========================================
  RESULTS
========================================
  Passed:  30
  Failed:  0

All tests passed! Fold v2 is working correctly.
```

## What Gets Tested

### V2 Features Validated
- ✅ Memory creation without type field
- ✅ Source detection (agent vs file)
- ✅ Decay-weighted search scoring
- ✅ Configurable strength_weight (0.0-1.0)
- ✅ Configurable decay_half_life_days
- ✅ Combined score calculation (0-weight×semantic + weight×strength)
- ✅ File chunking and AST parsing
- ✅ Chunk metadata accuracy (line numbers, node types, names)
- ✅ Chunk database storage (SQLite)
- ✅ Content hashing for deduplication
- ✅ Memory linking to chunks
- ✅ Search response structure with decay fields
- ✅ All major API endpoints
- ✅ Error validation (invalid parameters)

### Decay Algorithm Validation
Tests verify:
- Pure semantic search (weight=0): combined_score ≈ score
- Pure strength search (weight=1): combined_score ≈ strength
- Blended search (weight=0.5): combined_score = 0.5×score + 0.5×strength
- Configurable half-life affects decay rate
- Fresh memories have high strength
- Config changes immediately affect search results

### Database Validation
- Chunks table exists
- Chunks created for file memories
- Line numbers are 1-indexed and valid
- end_line >= start_line for all chunks
- All chunks have content_hash (no nulls)
- Chunks linked to parent memories
- Language detection working
- Chunk size statistics make sense

### API Validation
- All v2 endpoints functional
- Correct HTTP methods (GET, POST, PUT, DELETE)
- Proper error codes (400 for bad input)
- Response structures match v2 schema
- Authentication headers required
- Parameters properly validated

## Prerequisites

```powershell
# 1. Start Fold server
cd srv
cargo run

# 2. Start Qdrant (if not running)
docker run -p 6333:6333 -p 6334:6334 qdrant/qdrant

# 3. Create API token
cd test
$env:FOLD_TOKEN = powershell .\create-token.ps1
```

## Troubleshooting

### Database not found
```powershell
# Default path: D:\hh\git\g1\fold\srv\fold.db
# If different, update -DatabasePath parameter:
.\v2-comprehensive-smoke-test.ps1 -DatabasePath "C:\path\to\fold.db"
```

### Tests failing
1. Check server is running on port 8765
2. Verify Qdrant is running
3. Verify FOLD_TOKEN is set: `$env:FOLD_TOKEN`
4. Check database has proper permissions
5. Wait 3+ seconds for embeddings before search

### Chunks not found in database
1. Server may not have finished indexing (wait 2+ seconds)
2. File memories may not trigger chunking without proper configuration
3. Check database file exists and is readable
4. Verify file_path is included in memory request

## Performance Expectations

- Test completion: 30-60 seconds
- Database operations: <100ms each
- Search: 500-1000ms (includes embedding time)
- Decay config update: <100ms

## Success Criteria

✅ **Comprehensive Smoke Test**
- All 30+ tests pass
- No failed error handling tests
- Database records created successfully
- Decay scoring working correctly

✅ **Chunk Smoke Test**
- All 8 tests pass
- Chunks found in database
- Valid metadata in chunks
- Language detection working

## Files Generated During Tests

- Test projects created and deleted
- Memories created in database
- Chunks created in database
- Search index entries in Qdrant

All cleaned up automatically in final step.

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

Can be used in CI/CD pipelines:
```powershell
.\v2-comprehensive-smoke-test.ps1
if ($LASTEXITCODE -eq 0) {
    Write-Host "All tests passed!"
} else {
    Write-Host "Tests failed!"
    exit 1
}
```

## Next Steps

After smoke tests pass:
1. Run contract tests: `cargo test --test file_chunking_tests`
2. Run full test suite: `cargo test`
3. Performance benchmark with real project files
4. Load testing with concurrent operations

## References

- V2 Features: See `test/V2_MIGRATION_GUIDE.md`
- Chunking Details: See `test/CHUNKING_TEST_GUIDE.md`
- API Reference: See Fold API documentation
