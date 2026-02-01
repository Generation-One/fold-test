# Test Setup Guide

## Prerequisites

1. **Fold server** built and ready to run
2. **Qdrant** running (Docker)
3. **API credentials** configured

## Quick Start

### 1. Start Qdrant

```powershell
docker run -d -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

### 2. Configure Environment

Copy the example env file and add your keys:

```powershell
cd ../srv
cp .env.example .env
# Edit .env and add your GOOGLE_API_KEY
```

Required variables:
- `GOOGLE_API_KEY` - Your Gemini API key for embeddings

### 3. Start Fold Server

```powershell
cd ../srv
.\start-server.ps1
```

Wait for: `FOLD SERVER STARTED SUCCESSFULLY`

### 4. Create API Token

For initial setup without auth configured:
```powershell
# Bootstrap admin (first time only)
$body = @{
    token = "your-bootstrap-token-from-env"
    provider = "local"
    subject = "admin"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8765/auth/bootstrap" -Method POST -Body $body -ContentType "application/json"
```

### 5. Run Tests

```powershell
cd test
$env:FOLD_TOKEN = "your-api-token"
.\run-tests.ps1
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `FOLD_URL` | Server URL (default: http://localhost:8765) | No |
| `FOLD_TOKEN` | API token for authenticated endpoints | Yes |
| `GOOGLE_API_KEY` | Gemini API key (in srv/.env) | Yes |

## Troubleshooting

### Server won't start
- Check Qdrant is running: `curl http://localhost:6333/health`
- Check logs: `Get-Content $env:TEMP\fold-server.log`

### Tests fail with 401
- Ensure `FOLD_TOKEN` is set correctly
- Token may have expired - create a new one

### Embeddings not working
- Verify `GOOGLE_API_KEY` is set in `srv/.env`
- Check Gemini API quota at https://aistudio.google.com/
