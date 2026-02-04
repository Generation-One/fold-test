$headers = @{
    "Authorization" = "Bearer fold_AyFrCbbxYOKaRt1CW2hyz6sGuc2V1fb76ENtuX76"
    "Content-Type" = "application/json"
}

# Create a test project
$projectBody = @{
    name = "Test Project"
    slug = "test-$(Get-Date -Format 'HHmmss')"
    description = "Test project"
} | ConvertTo-Json

$proj = Invoke-RestMethod -Uri "http://localhost:8765/projects" -Method POST -Headers $headers -Body $projectBody
$projectId = $proj.id

# Create a memory
$memBody = @{
    title = "Test API"
    content = "This is about REST API authentication"
} | ConvertTo-Json

$mem = Invoke-RestMethod -Uri "http://localhost:8765/projects/$projectId/memories" -Method POST -Headers $headers -Body $memBody

# Wait for indexing
Start-Sleep -Seconds 2

# Search
$searchBody = @{ query = "authentication" } | ConvertTo-Json
$result = Invoke-RestMethod -Uri "http://localhost:8765/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody

Write-Host "Search results:"
if ($result.results.Count -gt 0) {
    Write-Host "First result fields:"
    $result.results[0].PSObject.Properties | ForEach-Object { Write-Host "  $($_.Name): $($_.Value)" }
} else {
    Write-Host "No results found"
}

# Cleanup
Invoke-RestMethod -Uri "http://localhost:8765/projects/$projectId" -Method DELETE -Headers $headers -ErrorAction SilentlyContinue
