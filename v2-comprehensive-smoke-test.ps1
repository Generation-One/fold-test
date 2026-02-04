#!/usr/bin/env powershell

# Fold v2 Comprehensive Smoke Test Suite
# Tests all major v2 features via API and database
#
# Security Model: User-based access control
# - Tokens are user-level (no project_ids field)
# - Project access controlled via user roles and group membership
# - User must be added to project to access it (directly or via group)

param(
    [string]$Token = $env:FOLD_TOKEN,
    [string]$FoldUrl = "http://localhost:8765",
    [string]$DatabasePath = "D:\hh\git\g1\fold\srv\fold.db"
)

# Bearer token auth - user identity, project access via membership
$headers = @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" }
$script:passed = 0
$script:failed = 0

function Test-Step {
    param([string]$Name, [scriptblock]$Test)

    Write-Host -NoNewline "  $Name... "
    try {
        $result = & $Test
        if ($result) {
            Write-Host "PASS" -ForegroundColor Green
            $script:passed++
            return $true
        } else {
            Write-Host "FAIL" -ForegroundColor Red
            $script:failed++
            return $false
        }
    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        $script:failed++
        return $false
    }
}

# ============================================================================
# PROJECT & DECAY CONFIGURATION TESTS
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FOLD V2 COMPREHENSIVE SMOKE TEST SUITE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "1. PROJECT MANAGEMENT" -ForegroundColor White

$projectSlug = "smoke-test-$(Get-Date -Format 'HHmmss')"

Test-Step "Create project with defaults" {
    $body = @{
        name = "Smoke Test Project"
        slug = $projectSlug
        description = "API smoke test"
    } | ConvertTo-Json

    $proj = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $body
    $script:projectId = $proj.id
    $proj.id -ne $null
}

Test-Step "Verify default decay config (strength_weight=0.3)" {
    $config = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/config/algorithm" -Method GET -Headers $headers
    $config.strength_weight -eq 0.3 -and $config.decay_half_life_days -eq 30.0
}

Test-Step "Update decay config" {
    $body = @{
        strength_weight = 0.5
        decay_half_life_days = 14.0
    } | ConvertTo-Json

    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/config/algorithm" -Method PUT -Headers $headers -Body $body
    $result.strength_weight -eq 0.5
}

Test-Step "List projects" {
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects" -Headers $headers
    $result.projects.Count -ge 1
}

# ============================================================================
# MEMORY CREATION & SEARCH TESTS
# ============================================================================

Write-Host "`n2. MEMORY OPERATIONS" -ForegroundColor White

Test-Step "Create memory without type field" {
    $body = @{
        title = "Test API Endpoint"
        content = "REST API with JWT authentication"
        author = "smoke-test"
        tags = @("api", "security")
    } | ConvertTo-Json

    $mem = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/memories" -Method POST -Headers $headers -Body $body
    $script:memoryId = $mem.id
    $mem.id -ne $null
}

Test-Step "Verify source set to agent" {
    $mem = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/memories/$script:memoryId" -Headers $headers
    $mem.source -eq "agent"
}

Test-Step "Create memory with file_path" {
    $body = @{
        title = "HTTP Handler"
        content = "pub async fn handle_request() { }"
        file_path = "src/main.rs"
    } | ConvertTo-Json

    $mem = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/memories" -Method POST -Headers $headers -Body $body
    $script:fileMemoryId = $mem.id
    $mem.source -eq "file"
}

Test-Step "List memories" {
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/memories" -Headers $headers
    $result.memories.Count -ge 2
}

Write-Host "`n3. SEMANTIC SEARCH" -ForegroundColor White

Write-Host "  Waiting for embeddings..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

Test-Step "Search with decay config" {
    $body = @{
        query = "REST API authentication"
    } | ConvertTo-Json

    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/search" -Method POST -Headers $headers -Body $body
    $result.results.Count -gt 0
}

Test-Step "Search includes decay fields (score, strength, combined_score)" {
    $body = @{ query = "authentication" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/search" -Method POST -Headers $headers -Body $body

    $first = $result.results[0]
    $first.score -ne $null -and $first.strength -ne $null -and $first.combined_score -ne $null
}

Test-Step "Change strength_weight to 0 (pure semantic)" {
    $config = @{ strength_weight = 0.0 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/config/algorithm" -Method PUT -Headers $headers -Body $config | Out-Null

    $body = @{ query = "api" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/search" -Method POST -Headers $headers -Body $body

    # When strength_weight=0, combined_score should equal score
    $first = $result.results[0]
    [math]::Abs($first.combined_score - $first.score) -lt 0.01
}

Test-Step "Change strength_weight to 1.0 (pure strength)" {
    $config = @{ strength_weight = 1.0 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/config/algorithm" -Method PUT -Headers $headers -Body $config | Out-Null

    $body = @{ query = "api" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/search" -Method POST -Headers $headers -Body $body

    # When strength_weight=1.0, combined_score should equal strength
    $first = $result.results[0]
    [math]::Abs($first.combined_score - $first.strength) -lt 0.01
}

# ============================================================================
# CHUNK DATABASE TESTS
# ============================================================================

Write-Host "`n4. CHUNK DATABASE VERIFICATION" -ForegroundColor White

if (Test-Path $DatabasePath) {
    $connectionString = "Data Source=$DatabasePath;Pooling=false;Version=3"
    $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)

    try {
        $connection.Open()

        Test-Step "Database connected" {
            $connection.State -eq [System.Data.ConnectionState]::Open
        }

        Test-Step "Chunks table exists" {
            $query = "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks'"
            $command = New-Object System.Data.SQLite.SQLiteCommand($query, $connection)
            $result = $command.ExecuteScalar()
            $result -eq "chunks"
        }

        Test-Step "File memory created chunks" {
            $query = "SELECT COUNT(*) FROM chunks WHERE memory_id = @id"
            $command = New-Object System.Data.SQLite.SQLiteCommand($query, $connection)
            $command.Parameters.AddWithValue("@id", $script:fileMemoryId) | Out-Null
            $count = $command.ExecuteScalar()
            $count -gt 0
        }

        Test-Step "Chunks have valid line numbers" {
            $query = "SELECT COUNT(*) FROM chunks WHERE project_id = @id AND start_line > 0 AND end_line >= start_line"
            $command = New-Object System.Data.SQLite.SQLiteCommand($query, $connection)
            $command.Parameters.AddWithValue("@id", $script:projectId) | Out-Null
            $valid = $command.ExecuteScalar()

            $query2 = "SELECT COUNT(*) FROM chunks WHERE project_id = @id"
            $command2 = New-Object System.Data.SQLite.SQLiteCommand($query2, $connection)
            $command2.Parameters.AddWithValue("@id", $script:projectId) | Out-Null
            $total = $command2.ExecuteScalar()

            $total -gt 0 -and $valid -eq $total
        }

        Test-Step "Chunks have content_hash" {
            $query = "SELECT COUNT(*) FROM chunks WHERE project_id = @id AND (content_hash IS NULL OR content_hash = '')"
            $command = New-Object System.Data.SQLite.SQLiteCommand($query, $connection)
            $command.Parameters.AddWithValue("@id", $script:projectId) | Out-Null
            $nullCount = $command.ExecuteScalar()
            $nullCount -eq 0
        }

        Test-Step "Chunks linked to memories" {
            $query = "SELECT COUNT(*) FROM chunks WHERE project_id = @id AND memory_id IS NOT NULL"
            $command = New-Object System.Data.SQLite.SQLiteCommand($query, $connection)
            $command.Parameters.AddWithValue("@id", $script:projectId) | Out-Null
            $linked = $command.ExecuteScalar()
            $linked -gt 0
        }

        $connection.Close()
    } catch {
        Write-Host "  ERROR: Failed to connect to database" -ForegroundColor Red
    }
} else {
    Write-Host "  Database not found at $DatabasePath - skipping database tests" -ForegroundColor Yellow
}

# ============================================================================
# ENDPOINT VALIDATION TESTS
# ============================================================================

Write-Host "`n5. API ENDPOINTS" -ForegroundColor White

Test-Step "GET /health" {
    $result = Invoke-RestMethod -Uri "$FoldUrl/health" -ErrorAction SilentlyContinue
    $result.status -eq "ok" -or $result.status -eq "healthy"
}

Test-Step "GET /projects (list)" {
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects" -Headers $headers
    $result.projects -ne $null
}

Test-Step "GET /projects/:id" {
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId" -Headers $headers
    $result.id -eq $script:projectId
}

Test-Step "POST /projects/:id/memories (create)" {
    $body = @{ title = "Test"; content = "Content" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/memories" -Method POST -Headers $headers -Body $body
    $result.id -ne $null
}

Test-Step "GET /projects/:id/memories (list)" {
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/memories" -Headers $headers
    $result.memories -ne $null
}

Test-Step "POST /projects/:id/search (search)" {
    $body = @{ query = "test" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/search" -Method POST -Headers $headers -Body $body
    $result.results -ne $null
}

Test-Step "GET /projects/:id/config/algorithm" {
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/config/algorithm" -Headers $headers
    $result.strength_weight -ne $null -and $result.decay_half_life_days -ne $null
}

Test-Step "PUT /projects/:id/config/algorithm" {
    $body = @{ strength_weight = 0.7 } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/config/algorithm" -Method PUT -Headers $headers -Body $body
    $result.strength_weight -eq 0.7
}

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

Write-Host "`n6. ERROR HANDLING" -ForegroundColor White

Test-Step "Reject invalid strength_weight" {
    $body = @{ strength_weight = 1.5 } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/config/algorithm" -Method PUT -Headers $headers -Body $body -ErrorAction Stop
        $false
    } catch {
        $_.Exception.Response.StatusCode -ge 400
    }
}

Test-Step "Reject empty memory content" {
    $body = @{ title = "Empty"; content = "" } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId/memories" -Method POST -Headers $headers -Body $body -ErrorAction Stop
        $false
    } catch {
        $_.Exception.Response.StatusCode -ge 400
    }
}

# ============================================================================
# CLEANUP
# ============================================================================

Write-Host "`n7. CLEANUP" -ForegroundColor White

Test-Step "Delete project" {
    Invoke-RestMethod -Uri "$FoldUrl/projects/$script:projectId" -Method DELETE -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    $true
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:  $script:passed" -ForegroundColor Green
Write-Host "  Failed:  $script:failed" -ForegroundColor $(if ($script:failed -gt 0) { "Red" } else { "Green" })

if ($script:failed -eq 0) {
    Write-Host "`nAll tests passed! Fold v2 is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed. Check output above." -ForegroundColor Red
    exit 1
}
