# Test Setup Guide

## Prerequisites

1. **Fold server** built and ready to run
2. **Qdrant** running (Docker)
3. **Gemini API key** for embeddings
4. **gh CLI** (optional, for PR workflow testing)

## Quick Start

### 1. Start Qdrant

```powershell
docker run -d -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

### 2. Configure Environment

Edit `srv/.env` and set your Gemini API key:

```env
GOOGLE_API_KEY=your-gemini-api-key-here
```

Get a free Gemini API key at: https://aistudio.google.com/

### 3. Start Fold Server

From PowerShell:
```powershell
cd srv
.\start-server.ps1
```

Or from bash (for Claude):
```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "d:/hh/git/g1/fold/srv/start-server.ps1"
```

Wait for: `FOLD SERVER STARTED SUCCESSFULLY`

### 4. Create API Token

Use the provided script to create a test token:

```powershell
cd test
.\create-token.ps1
```

This outputs a token like `fold_abc123...`. Save it for testing.

**Note:** The script inserts directly into SQLite. Requires an existing user in the database.

### 5. Run Tests

```powershell
cd test
.\run-tests.ps1 -Token "fold_your-token-here"
```

Or set environment variable:
```powershell
$env:FOLD_TOKEN = "fold_your-token-here"
.\run-tests.ps1
```

## Test Token Details

The `create-token.ps1` script:
- Generates a random 45-character token (`fold_` + 40 chars)
- Hashes the full token with SHA256
- Stores hash and 8-char prefix in `api_tokens` table
- Token format: `fold_{8-char-prefix}{32-char-secret}`

To create a token manually:
```sql
-- Token prefix is first 8 chars after "fold_"
-- Token hash is SHA256 of the FULL token string
INSERT INTO api_tokens (id, user_id, name, token_hash, token_prefix, project_ids, created_at)
VALUES ('uuid', 'user-id', 'Test Token', 'sha256-hash', 'prefix8c', '[]', datetime('now'));
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `FOLD_URL` | Server URL (default: http://localhost:8765) | No |
| `FOLD_TOKEN` | API token for authenticated endpoints | Yes |
| `GOOGLE_API_KEY` | Gemini API key (in srv/.env) | Yes |

## Server Management

### Check Server Status
```powershell
cd srv
.\check-server.ps1
```

### Stop Server
```powershell
cd srv
.\stop-server.ps1
```

### View Logs
```powershell
Get-Content $env:TEMP\fold-server.log -Tail 50
Get-Content $env:TEMP\fold-server-err.log -Tail 50
```

## Git Workflow Testing

### Install gh CLI
```powershell
winget install GitHub.cli
gh auth login
```

### Create PR
```powershell
cd test
git checkout -b feature/my-feature
# Make changes...
git add .
git commit -m "Description

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push -u origin feature/my-feature
gh pr create --title "Title" --body "## Summary
- Change 1
- Change 2

## Test plan
- [x] Tests pass"
```

## Troubleshooting

### Server won't start
- Check Qdrant is running: `curl http://localhost:6333/health`
- Check logs: `Get-Content $env:TEMP\fold-server.log`
- Check error logs: `Get-Content $env:TEMP\fold-server-err.log`

### Tests fail with 401 / Invalid Token
- Ensure `FOLD_TOKEN` is set correctly
- Token prefix must be exactly 8 chars after `fold_`
- Verify token exists: `sqlite3 srv/data/fold.db "SELECT token_prefix FROM api_tokens"`

### Embeddings not working / degraded status
- Verify `GOOGLE_API_KEY` is set in `srv/.env`
- Restart server after changing `.env`
- Check health: `curl http://localhost:8765/health/ready`
- Check Gemini API quota at https://aistudio.google.com/

### PowerShell scripts fail from bash
Use `powershell.exe` directly:
```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "path/to/script.ps1"
```
