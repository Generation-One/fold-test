# Create a test API token for Fold
param(
    [string]$UserId = "a194b1eb-e843-42ac-9dce-0d988d643582",  # Frank's user ID
    [string]$DbPath = "d:\hh\git\g1\fold\srv\data\fold.db"
)

# Generate random token body (alphanumeric)
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$tokenBody = [Convert]::ToBase64String($bytes) -replace '[+/=]',''
$tokenBody = $tokenBody.Substring(0, 40)
$token = "fold_" + $tokenBody

# Hash the FULL token (SHA256)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($token))
$hash = [BitConverter]::ToString($hashBytes) -replace '-',''
$hash = $hash.ToLower()

# Prefix is first 8 chars AFTER "fold_"
$prefix = $tokenBody.Substring(0, 8)

# Generate UUID for token ID
$tokenId = [guid]::NewGuid().ToString()

# Insert into database
$sql = @"
INSERT INTO api_tokens (id, user_id, name, token_hash, token_prefix, project_ids, created_at)
VALUES ('$tokenId', '$UserId', 'Test Token', '$hash', '$prefix', '[]', datetime('now'));
"@

try {
    sqlite3 $DbPath $sql
    Write-Host "Token created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "FOLD_TOKEN=$token" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Set this in your environment:" -ForegroundColor Yellow
    Write-Host "`$env:FOLD_TOKEN = `"$token`""
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
