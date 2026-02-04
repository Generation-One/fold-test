#!/usr/bin/env powershell

# Test what search returns - specifically check if content/summary is included

$headers = @{
    "Authorization" = "Bearer fold_yKGKF0kcvkJDEO4TqV5xY3oK2xsTZR3rb5xQA7iO"
    "Content-Type" = "application/json"
}

Write-Host "Creating test project..." -ForegroundColor Cyan
$projectBody = @{
    name = "Search Content Test"
    slug = "search-content-$(Get-Date -Format 'HHmmss')"
    description = "Test to verify search results include summaries"
} | ConvertTo-Json

$project = Invoke-RestMethod -Uri "http://localhost:8765/projects" -Method POST -Headers $headers -Body $projectBody -TimeoutSec 10
$projectId = $project.id
$projectSlug = $project.slug

Write-Host "Project ID: $projectId`n" -ForegroundColor Green

# Add a TypeScript file with actual code
Write-Host "Adding TypeScript file..." -ForegroundColor Cyan
$tsContent = @"
export interface UserService {
  findById(id: string): Promise<User>;
  create(user: CreateUserInput): Promise<User>;
  update(id: string, input: UpdateUserInput): Promise<User>;
  delete(id: string): Promise<void>;
}

export async function getUserById(id: string): Promise<User> {
  // This function retrieves a user by their ID from the database
  const user = await db.users.findOne({ id });
  if (!user) {
    throw new Error('User not found');
  }
  return user;
}

export class UserController {
  constructor(private service: UserService) {}

  async handleGetUser(req, res) {
    const user = await this.service.findById(req.params.id);
    res.json(user);
  }
}
"@

$memBody = @{
    title = "User Service Implementation"
    content = $tsContent
    file_path = "user-service.ts"
    author = "test"
} | ConvertTo-Json -Depth 10

$mem = Invoke-RestMethod -Uri "http://localhost:8765/projects/$projectId/memories" -Method POST -Headers $headers -Body $memBody -TimeoutSec 60
Write-Host "Memory created: $($mem.id)`n" -ForegroundColor Green

Start-Sleep -Seconds 2

# Search for "function"
Write-Host "Searching for 'function'..." -ForegroundColor Cyan
$searchBody = @{ query = "function"; include_chunks = $true; min_score = 0.0 } | ConvertTo-Json
$results = Invoke-RestMethod -Uri "http://localhost:8765/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody -TimeoutSec 30

Write-Host "Found $($results.results.Count) results`n" -ForegroundColor Green

if ($results.results.Count -gt 0) {
    $first = $results.results[0]
    Write-Host "=== FIRST RESULT ===" -ForegroundColor Yellow
    Write-Host "ID: $($first.id)" -ForegroundColor Gray
    Write-Host "Title: $($first.title)" -ForegroundColor Gray
    Write-Host "Score: $($first.score)" -ForegroundColor Gray
    Write-Host "Source: $($first.metadata.source)" -ForegroundColor Gray
    Write-Host "File: $($first.metadata.file_path)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "=== CONTENT (Summary) ===" -ForegroundColor Yellow
    if ($first.content -and $first.content.Length -gt 0) {
        Write-Host $first.content -ForegroundColor Green
    } else {
        Write-Host "(No content in result)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "=== SNIPPET ===" -ForegroundColor Yellow
    if ($first.snippet -and $first.snippet.Length -gt 0) {
        Write-Host $first.snippet -ForegroundColor Green
    } else {
        Write-Host "(No snippet in result)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "=== MATCHED CHUNKS ===" -ForegroundColor Yellow
    if ($first.matched_chunks -and $first.matched_chunks.Count -gt 0) {
        Write-Host "Found $($first.matched_chunks.Count) matched chunks:" -ForegroundColor Gray
        $first.matched_chunks | ForEach-Object {
            Write-Host "  - Type: $($_.node_type), Score: $($_.score)" -ForegroundColor Gray
        }
    } else {
        Write-Host "(No matched chunks)" -ForegroundColor Gray
    }
}

# Cleanup
Write-Host "`nCleaning up..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "http://localhost:8765/projects/$projectId" -Method DELETE -Headers $headers -TimeoutSec 10 | Out-Null
Write-Host "Done!" -ForegroundColor Green
