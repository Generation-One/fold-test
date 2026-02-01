# Fold Test Plan

## Overview

This folder contains test files and scripts to verify Fold's core functionality:
- API endpoints
- Database operations
- File sync/indexing
- Embedding generation (Gemini)
- MCP tools

## Prerequisites

1. **Fold server running** on `http://localhost:8765`
2. **Qdrant** running on `http://localhost:6334`
3. **Gemini API key** in `srv/.env` as `GOOGLE_API_KEY`

## Test Categories

### 1. Health & Connectivity
- [ ] Server health endpoint responds
- [ ] Qdrant connection works
- [ ] Database is accessible

### 2. Project Management
- [ ] Create project
- [ ] List projects
- [ ] Get project by ID
- [ ] Delete project

### 3. Memory Operations
- [ ] Add memory (manual)
- [ ] List memories
- [ ] Search memories (semantic)
- [ ] Update memory
- [ ] Delete memory

### 4. File Indexing
- [ ] Index a file manually via API
- [ ] Verify embedding was created
- [ ] Search finds the indexed file

### 5. Embedding Generation
- [ ] Gemini provider responds
- [ ] Embeddings are generated correctly
- [ ] Vector stored in Qdrant

### 6. Git Sync (if configured)
- [ ] Webhook receives push events
- [ ] Files are indexed on push
- [ ] Commit summaries generated

### 7. Git Workflow (PR & Commits)
- [ ] Create commit with proper format
- [ ] Commit message follows conventions
- [ ] Co-Author line included
- [ ] Create PR with summary and test plan
- [ ] PR description is well-formatted
- [ ] Changes pushed to remote branch

## Running Tests

```powershell
# From the test folder
.\run-tests.ps1

# Or individual test scripts
.\tests\01-health.ps1
.\tests\02-projects.ps1
.\tests\03-memories.ps1
```

## Test Data

Sample files in `sample-files/` are used for indexing tests:
- `sample.ts` - TypeScript file
- `sample.py` - Python file
- `sample.md` - Markdown documentation

## Environment

Tests expect these environment variables (or use defaults):
- `FOLD_URL` - Server URL (default: `http://localhost:8765`)
- `FOLD_TOKEN` - API token (required for authenticated endpoints)
