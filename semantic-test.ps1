# Semantic Search Test Script
# Creates memories and tests that semantic search returns correct results

param(
    [string]$Token = $env:FOLD_TOKEN,
    [string]$FoldUrl = "http://localhost:8765"
)

$headers = @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SEMANTIC SEARCH VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Create test project
Write-Host "Creating test project..." -ForegroundColor White
$projectBody = @{
    name = "semantic-test"
    slug = "sem-test-$(Get-Date -Format 'HHmmss')"
    description = "Testing semantic vector search"
} | ConvertTo-Json

$project = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $projectBody
$projectId = $project.id
Write-Host "  Project: $($project.name) [$projectId]" -ForegroundColor Green

# Add diverse memories
Write-Host "`nAdding test memories..." -ForegroundColor White

$memories = @(
    @{
        title = "User Login System"
        content = "The authentication module uses JWT tokens with RSA-256 signing. Users log in with email and password, which is validated against bcrypt hashes in the database. Sessions expire after 24 hours and require re-authentication."
    },
    @{
        title = "ETL Pipeline Design"
        content = "We chose Apache Kafka for the data ingestion layer because it handles high throughput message streaming. Data is transformed using Spark jobs and loaded into PostgreSQL for analytics queries."
    },
    @{
        title = "Database Schema"
        content = "The users table contains id, email, password_hash, created_at, and last_login fields. Foreign keys link to orders, preferences, and sessions tables. We use PostgreSQL with connection pooling via PgBouncer."
    },
    @{
        title = "React Dashboard"
        content = "The dashboard uses React 18 with TypeScript. State management is handled by Zustand. Components include charts from Recharts library, tables with virtualization, and real-time updates via WebSocket connections."
    },
    @{
        title = "Cloud Infrastructure"
        content = "Kubernetes cluster on AWS EKS handles container orchestration. We use Terraform for infrastructure as code, with separate staging and production environments. Auto-scaling is configured based on CPU utilization."
    }
)

foreach ($mem in $memories) {
    $body = $mem | ConvertTo-Json
    $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $body
    Write-Host "  Added: $($r.title)" -ForegroundColor Gray
}

Write-Host "`nWaiting 5 seconds for embeddings..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Test semantic searches
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SEMANTIC SEARCH TESTS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$script:passed = 0
$script:failed = 0

function Test-SemanticSearch {
    param(
        [string]$Query,
        [string]$ExpectedTitle,
        [string]$Reason
    )

    Write-Host -NoNewline "  Query: `"$Query`" -> "

    $searchBody = @{ query = $Query } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody

    if ($result.results.Count -eq 0) {
        Write-Host "FAIL (no results)" -ForegroundColor Red
        $script:failed++
        return
    }

    $topResult = $result.results[0]
    $topTitle = $topResult.title
    $score = [math]::Round($topResult.score, 3)

    if ($topTitle -eq $ExpectedTitle) {
        Write-Host "PASS" -ForegroundColor Green
        Write-Host "    Top result: `"$topTitle`" (score: $score)" -ForegroundColor Gray
        Write-Host "    Reason: $Reason" -ForegroundColor DarkGray
        $script:passed++
    } else {
        Write-Host "FAIL" -ForegroundColor Red
        Write-Host "    Expected: `"$ExpectedTitle`"" -ForegroundColor Yellow
        Write-Host "    Got: `"$topTitle`" (score: $score)" -ForegroundColor Yellow
        $script:failed++
    }
}

# Test 1: Security/auth query should find Login System
Test-SemanticSearch -Query "how do users authenticate and verify their identity" -ExpectedTitle "User Login System" -Reason "Query about authentication should match JWT/login content"

# Test 2: Streaming data query should find ETL Pipeline
Test-SemanticSearch -Query "processing real-time data streams and analytics" -ExpectedTitle "ETL Pipeline Design" -Reason "Query about data streaming should match Kafka/Spark content"

# Test 3: Database structure query should find Database Schema
Test-SemanticSearch -Query "what columns and fields are in the user database table" -ExpectedTitle "Database Schema" -Reason "Query about database structure should match schema content"

# Test 4: Frontend UI query should find React Dashboard
Test-SemanticSearch -Query "displaying data visualizations and charts in the browser" -ExpectedTitle "React Dashboard" -Reason "Query about UI charts should match React/Recharts content"

# Test 5: DevOps query should find Cloud Infrastructure
Test-SemanticSearch -Query "deploying containers and managing server scaling" -ExpectedTitle "Cloud Infrastructure" -Reason "Query about deployment should match Kubernetes/EKS content"

# Test 6: Different wording for auth
Test-SemanticSearch -Query "password hashing and session management" -ExpectedTitle "User Login System" -Reason "Security terms should match authentication content"

# Test 7: Different wording for data processing
Test-SemanticSearch -Query "message queues and batch data transformation" -ExpectedTitle "ETL Pipeline Design" -Reason "Data pipeline terms should match Kafka/Spark content"

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:  $script:passed" -ForegroundColor Green
Write-Host "  Failed:  $script:failed" -ForegroundColor $(if ($script:failed -gt 0) { "Red" } else { "Green" })

# Cleanup
Write-Host "`nCleaning up test project..." -ForegroundColor Gray
Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId" -Method DELETE -Headers $headers -ErrorAction SilentlyContinue | Out-Null

if ($script:failed -gt 0) {
    exit 1
} else {
    Write-Host "`nSemantic search is working correctly!" -ForegroundColor Green
    exit 0
}
