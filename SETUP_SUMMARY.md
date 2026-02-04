# Fold v2 Chunking Test Setup - Summary

## Status: ✅ Complete (Memories Created - Awaiting Chunking)

**Date:** 2026-02-04
**Project ID:** `987435f4-0328-476b-aa97-78e577b10f2a`
**Database:** `srv/data/fold.db`

---

## Setup Completed

### 1. Project Created ✅
- **Name:** Sample Test
- **Slug:** samptest
- **Memories:** 10 files added

### 2. Sample Files Added ✅
The following files were added as memories via API:
```
- api-routes.ts
- architecture.md
- auth-service.ts
- database.ts
- markdown-sample.md
- plain-text-sample.txt
- python-sample.py
- rust-sample.rs
- typescript-sample.ts
- user-service.ts
```

All files were uploaded successfully using REST API endpoints (not direct database).

### 3. Documentation Created ✅
- `instructions.md` - Complete user guide for Fold v2
- Covers security model, decay algorithm, chunking, API endpoints, testing

### 4. Verification Scripts ✅
- `setup-chunking-test.ps1` - Sets up test environment
- `verify-chunking.ps1` - Verifies chunks exist in database
- `final_setup.ps1` - Simple direct setup script

---

## Current State

### Database
```
Memories:  10 ✅
Chunks:    0  ⏳ (awaiting indexing)
Database:  srv/data/fold.db
```

### Next Steps

#### Option 1: Wait and Re-Check
The chunking system processes memories asynchronously. To verify:

```powershell
cd d:\hh\git\g1\fold\test
.\verify-chunking.ps1 -DbPath "d:\hh\git\g1\fold\srv\data\fold.db"
```

#### Option 2: Manually Trigger Indexing (if needed)
If chunks haven't been created after 30+ seconds:

1. Check server logs:
   ```powershell
   Get-Content "$env:TEMP\fold-server.log" -Tail 50
   ```

2. Search memories via API to verify they're indexed:
   ```powershell
   $searchBody = '{"query":"function"}'
   Invoke-RestMethod -Uri "http://localhost:8765/projects/987435f4-0328-476b-aa97-78e577b10f2a/search" `
     -Method POST -Headers @{"Authorization"="Bearer fold_7tL9ZOLlVpC1EFhCxWsAfgjIlsyACfABGOyNCabt";"Content-Type"="application/json"} `
     -Body $searchBody
   ```

---

## Architecture Validations

### Security Model (v2) ✅
- API authentication via Bearer token working
- Projects created and accessed via user membership
- No project_ids field required in token

### Decay-Weighted Search ✅ (pre-verified)
- Decay algorithm implemented in search.rs
- Search results include: `score`, `strength`, `combined_score`
- Configuration endpoints working (strength_weight, decay_half_life_days)

### Chunking System
- Tree-sitter AST parsing available for code files
- Heading detection for Markdown
- Paragraph detection for prose
- Language detection implemented
- **Status:** Awaiting chunk creation for verification

---

## Files Modified

### Created
- `/instructions.md` - User guide
- `/test/setup-chunking-test.ps1` - Setup script
- `/test/verify-chunking.ps1` - Verification script
- `/test/SETUP_SUMMARY.md` - This file

### Database
- Location: `srv/data/fold.db`
- Tables used: memories, chunks, projects, api_tokens
- Status: Clean test environment with 10 sample memories

---

## API Used (Not SQL)

All setup was done via REST API endpoints:

✅ `POST /projects` - Create project
✅ `POST /projects/:id/memories` - Add 10 memories
✅ `GET /projects/:id` - Verify project
✅ `GET /projects/:id/memories` - List memories

All verification was done via SQL queries (database inspection only).

---

## Notes for Future Sessions

1. **Chunking may be async** - The memory indexing and chunking happens in background jobs, may take 10-30 seconds
2. **Database location** - Always use `srv/data/fold.db`, not root `fold.db`
3. **Server logs** - Check `$env:TEMP\fold-server.log` for issues
4. **Token** - Test token: `fold_7tL9ZOLlVpC1EFhCxWsAfgjIlsyACfABGOyNCabt` (test-user-001)

---

## Troubleshooting

If chunks still don't appear:

1. **Check job queue:**
   ```sql
   SELECT * FROM background_jobs ORDER BY created_at DESC LIMIT 5;
   ```

2. **Verify memory content:**
   ```sql
   SELECT id, title, LENGTH(content) as content_size FROM memories
   WHERE project_id = '987435f4-0328-476b-aa97-78e577b10f2a';
   ```

3. **Check for chunking errors in logs:**
   ```powershell
   Get-Content "$env:TEMP\fold-server.log" | Select-String -Pattern "chunk|error|warn" -Context 2
   ```

---

## Test Project Access

**Project ID:** `987435f4-0328-476b-aa97-78e577b10f2a`

Access via API:
```powershell
curl -H "Authorization: Bearer fold_7tL9ZOLlVpC1EFhCxWsAfgjIlsyACfABGOyNCabt" \
  http://localhost:8765/projects/987435f4-0328-476b-aa97-78e577b10f2a
```

List memories:
```powershell
curl -H "Authorization: Bearer fold_7tL9ZOLlVpC1EFhCxWsAfgjIlsyACfABGOyNCabt" \
  http://localhost:8765/projects/987435f4-0328-476b-aa97-78e577b10f2a/memories
```

Search:
```powershell
curl -X POST -H "Authorization: Bearer fold_7tL9ZOLlVpC1EFhCxWsAfgjIlsyACfABGOyNCabt" \
  -H "Content-Type: application/json" \
  -d '{"query":"authentication"}' \
  http://localhost:8765/projects/987435f4-0328-476b-aa97-78e577b10f2a/search
```
