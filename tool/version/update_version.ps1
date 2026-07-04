# PowerShell script to update version across all files
param(
    [string]$VersionFile = $(Join-Path $PSScriptRoot "version.json")
)

# ---- Encoding helpers ----
# Explicit UTF-8 encodings to avoid PS version differences (PS5 adds BOM by default)
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)  # for .gitignore, yaml, etc.
$Utf8Bom   = New-Object System.Text.UTF8Encoding($true)   # for Inno Setup .iss files

# Read version from JSON file
if (-not (Test-Path $VersionFile)) {
    Write-Error "Version file '$VersionFile' not found!"
    exit 1
}

$versionData = Get-Content $VersionFile | ConvertFrom-Json
$newVersion = $versionData.version

function Get-VersionCode {
    param(
        [string]$Version
    )

    $versionParts = $Version.Split('.')
    if ($versionParts.Length -ne 3) {
        throw "Version '$Version' must have format major.minor.patch"
    }

    $major = [int64]$versionParts[0]
    $minor = [int64]$versionParts[1]
    $patch = [int64]$versionParts[2]

    # Keep the last digit available for manual hotfix bumps while preserving
    # monotonic ordering across major/minor/patch increments.
    return (($major * 1000000) + ($minor * 10000) + ($patch * 10)).ToString()
}

$versionCode = Get-VersionCode -Version $newVersion

Write-Host "Updating version to: $newVersion"

# Update .gitignore (managed Windows installer outputs)
$installerStartMarker = "# Generated Windows installers"
$installerEndMarker = "# End generated Windows installers"
$managedInstallerLines = @(
    "installer/otzaria-$newVersion-windows.exe",
    "installer/otzaria-$newVersion-windows-full.exe"
)
$gitignoreContent = [System.Collections.Generic.List[string]]::new()
$gitignoreContent.AddRange([string[]](Get-Content ".gitignore"))
$filteredGitignore = [System.Collections.Generic.List[string]]::new()
$insideManagedInstallerBlock = $false
$insertedInstallerBlock = $false
foreach ($line in $gitignoreContent) {
    if ($line -eq $installerStartMarker) {
        $insideManagedInstallerBlock = $true
        continue
    }
    if ($line -eq $installerEndMarker) {
        $insideManagedInstallerBlock = $false
        continue
    }
    if ($insideManagedInstallerBlock) {
        continue
    }
    if ($line -match '^installer/otzaria-[0-9.]+-windows(?:-full)?(?:-silent)?\.exe$') {
        continue
    }

    $filteredGitignore.Add($line)

    if (-not $insertedInstallerBlock -and $line -eq "external/") {
        $filteredGitignore.Add($installerStartMarker)
        foreach ($installerLine in $managedInstallerLines) {
            $filteredGitignore.Add($installerLine)
        }
        $filteredGitignore.Add($installerEndMarker)
        $insertedInstallerBlock = $true
    }
}
if (-not $insertedInstallerBlock) {
    if ($filteredGitignore.Count -gt 0 -and $filteredGitignore[$filteredGitignore.Count - 1] -ne "") {
        $filteredGitignore.Add("")
    }
    $filteredGitignore.Add($installerStartMarker)
    foreach ($installerLine in $managedInstallerLines) {
        $filteredGitignore.Add($installerLine)
    }
    $filteredGitignore.Add($installerEndMarker)
}
$filteredGitignore | Set-Content ".gitignore" -Encoding $Utf8NoBom
Write-Host "Updated .gitignore"

# Update pubspec.yaml: msix_version (4-part) and version (with build code).
$pubspecContent = Get-Content "pubspec.yaml"

for ($i = 0; $i -lt $pubspecContent.Length; $i++) {
    # msix_version uses 4 parts: major.minor.patch.build
    if ($pubspecContent[$i] -match "^(\s*)msix_version:\s*") {
        $pubspecContent[$i] = "$($matches[1])msix_version: $newVersion.0"
    }
    # Top-level version (no leading whitespace) — keep this check AFTER msix_version
    # so the more specific key isn't shadowed.
    elseif ($pubspecContent[$i] -match "^version:\s*") {
        $pubspecContent[$i] = "version: $newVersion+$versionCode"
    }
}
$pubspecContent | Set-Content "pubspec.yaml" -Encoding $Utf8NoBom
Write-Host "Updated pubspec.yaml (version: $newVersion+$versionCode, msix_version: $newVersion.0)"

# Update installer/otzaria_full.iss (line 5)
$fullIssContent = Get-Content "installer/otzaria_full.iss"
for ($i = 0; $i -lt $fullIssContent.Length; $i++) {
    if ($fullIssContent[$i] -match '^#define MyAppVersion\s+') {
        $fullIssContent[$i] = "#define MyAppVersion `"$newVersion`""
    }
}
$fullIssContent | Set-Content "installer/otzaria_full.iss" -Encoding $Utf8Bom
Write-Host "Updated installer/otzaria_full.iss"

# Update installer/otzaria.iss (line 5)
$issContent = Get-Content "installer/otzaria.iss"
for ($i = 0; $i -lt $issContent.Length; $i++) {
    if ($issContent[$i] -match '^#define MyAppVersion\s+') {
        $issContent[$i] = "#define MyAppVersion `"$newVersion`""
    }
}
$issContent | Set-Content "installer/otzaria.iss" -Encoding $Utf8Bom
Write-Host "Updated installer/otzaria.iss"

# Update android/local.properties (versionName and versionCode)
$localPropertiesFile = "android/local.properties"
if (Test-Path $localPropertiesFile) {
    $localPropsContent = Get-Content $localPropertiesFile
    $versionNameFound = $false
    $versionCodeFound = $false
    
    for ($i = 0; $i -lt $localPropsContent.Length; $i++) {
        if ($localPropsContent[$i] -match "^flutter\.versionName=") {
            $localPropsContent[$i] = "flutter.versionName=$newVersion"
            $versionNameFound = $true
        }
        if ($localPropsContent[$i] -match "^flutter\.versionCode=") {
            $localPropsContent[$i] = "flutter.versionCode=$versionCode"
            $versionCodeFound = $true
        }
    }
    
    # Add missing properties if not found
    if (-not $versionNameFound) {
        $localPropsContent += "flutter.versionName=$newVersion"
    }
    if (-not $versionCodeFound) {
        $localPropsContent += "flutter.versionCode=$versionCode"
    }
    
    $localPropsContent | Set-Content $localPropertiesFile -Encoding $Utf8NoBom
    Write-Host "Updated $localPropertiesFile (versionName=$newVersion, versionCode=$versionCode)"
} else {
    Write-Warning "File '$localPropertiesFile' not found! Skipping Android version update."
}

# Update lib/main.dart (_latestReleasedBuildNumber constant)
$mainDartFile = "lib/main.dart"
if (Test-Path $mainDartFile) {
    $mainDartContent = Get-Content $mainDartFile
    for ($i = 0; $i -lt $mainDartContent.Length; $i++) {
        if ($mainDartContent[$i] -match '^const int _latestReleasedBuildNumber\s*=\s*\d+;') {
            $mainDartContent[$i] = "const int _latestReleasedBuildNumber = $versionCode;"
        }
    }
    $mainDartContent | Set-Content $mainDartFile -Encoding $Utf8NoBom
    Write-Host "Updated $mainDartFile (_latestReleasedBuildNumber = $versionCode)"
} else {
    Write-Warning "File '$mainDartFile' not found! Skipping main.dart update."
}

# Update macos/Runner.xcodeproj/project.pbxproj (MARKETING_VERSION and CURRENT_PROJECT_VERSION)
$pbxprojFile = "macos/Runner.xcodeproj/project.pbxproj"
if (Test-Path $pbxprojFile) {
    $pbxprojContent = Get-Content $pbxprojFile
    for ($i = 0; $i -lt $pbxprojContent.Length; $i++) {
        $pbxprojContent[$i] = $pbxprojContent[$i] -replace 'MARKETING_VERSION = [0-9.]+;', "MARKETING_VERSION = $newVersion;"
        $pbxprojContent[$i] = $pbxprojContent[$i] -replace 'CURRENT_PROJECT_VERSION = [0-9]+;', "CURRENT_PROJECT_VERSION = $versionCode;"
    }
    $pbxprojContent | Set-Content $pbxprojFile -Encoding $Utf8NoBom
    Write-Host "Updated $pbxprojFile (MARKETING_VERSION=$newVersion, CURRENT_PROJECT_VERSION=$versionCode)"
} else {
    Write-Warning "File '$pbxprojFile' not found! Skipping macOS project update."
}

# Update assets/יומן שינויים.md (Add new version as first item)
$changelogFile = "assets/יומן שינויים.md"
# 1. REMOVE the leading `n` from the version line itself
$changelogVersionLine = "* **$newVersion**" # The version line in Markdown format (NO leading newline)

if (Test-Path $changelogFile) {
    # Read existing content
    $existingContent = Get-Content $changelogFile -Raw -Encoding $Utf8NoBom

    # 2. Add the NEW version line followed by a single newline
    $newChangelogContent = $changelogVersionLine + "`n" + $existingContent

    # 3. Write back to the file
    $newChangelogContent | Set-Content $changelogFile -Encoding $Utf8NoBom
    Write-Host "Updated $changelogFile with new version: $newVersion"
} else {
    Write-Warning "Changelog file '$changelogFile' not found! Skipping changelog update."
}

Write-Host "Version update completed successfully!"
Write-Host "All files have been updated to version: $newVersion"

# Git commit
$filesToStage = @(".gitignore", "pubspec.yaml", "installer/otzaria_full.iss", "installer/otzaria.iss", $changelogFile, $VersionFile, $mainDartFile)
git add $filesToStage
# project.pbxproj is tracked but lives under a path matched by .gitignore (macos/*),
# so plain `git add` warns — -f forces the add for this already-tracked file.
if (Test-Path $pbxprojFile) { git add -f $pbxprojFile }
git commit -m "$newVersion"
Write-Host "Git commit created for version: $newVersion"
