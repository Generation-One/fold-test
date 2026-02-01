# Fold Test Plan

## Overview

This folder contains test files and scripts to verify Fold's core functionality:
- API endpoints
- Database operations
- Semantic search with embeddings
- Embedding generation (Gemini)
- Project configuration
- Git workflow (commits & PRs)

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
| `create-token.ps1` | Generate API token for testing |

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

## Troubleshooting

See [setup.md](setup.md#troubleshooting) for common issues and solutions.
