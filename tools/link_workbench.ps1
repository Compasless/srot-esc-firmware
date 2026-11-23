param(
    [Parameter(Mandatory=$true)][string]$WorkbenchRoot,
    [string]$RepositoryParent = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workbenchPath = (Resolve-Path -LiteralPath $WorkbenchRoot).Path
$repositoryPath = (Resolve-Path -LiteralPath $RepositoryParent).Path
$names = 'srot-control-board','srot-ground-station','srot-esc-flasher','srot-esc-firmware'
foreach ($name in $names) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryPath "$name\.git"))) {
        throw "Missing repository: $name"
    }
}
$aliasRoot = Join-Path $workbenchPath 'repos'
New-Item -ItemType Directory -Path $aliasRoot -Force | Out-Null
foreach ($name in $names) {
    $target = (Resolve-Path -LiteralPath (Join-Path $repositoryPath $name)).Path
    $link = Join-Path $aliasRoot $name
    if (Test-Path -LiteralPath $link) {
        $item = Get-Item -LiteralPath $link
        if ($item.LinkType -ne 'Junction' -or $item.Target -ne $target) {
            throw "Existing path is not the expected repository junction: $link"
        }
    } else {
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    }
}
$templates = Join-Path $projectRoot 'workbench'
Get-ChildItem -LiteralPath $templates -Recurse -File | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($templates, $_.FullName)
    $destination = Join-Path $workbenchPath $relative
    if (Test-Path -LiteralPath $destination) {
        $existing = [IO.File]::ReadAllText($destination).Replace([string][char]13, '').TrimEnd()
        $expected = [IO.File]::ReadAllText($_.FullName).Replace([string][char]13, '').TrimEnd()
        if ($existing -ne $expected) {
            throw "Preserving different existing workbench file: $destination"
        }
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destination
    }
}
Write-Output "Workbench linked to four independent repositories: $workbenchPath"
