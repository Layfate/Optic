param([string]$RojoPath = 'rojo')
$ErrorActionPreference = 'Stop'
$opticProjectRoot = Split-Path -Parent $PSScriptRoot
$opticRojoCommand = Get-Command -Name $RojoPath -ErrorAction Stop
$opticBinaryPath = Join-Path $opticProjectRoot 'dist\Optic.rbxm'
$opticValidationRoot = Join-Path $opticProjectRoot 'test-results'
New-Item -ItemType Directory -Path $opticValidationRoot -Force | Out-Null
$opticRoundtripProject = Join-Path $opticValidationRoot 'optic-roundtrip.project.json'
$opticRoundtripXml = Join-Path $opticValidationRoot 'Optic-roundtrip.rbxmx'
$opticProjectJson = @{name='Optic';tree=@{'$path'='../dist/Optic.rbxm'}} | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText($opticRoundtripProject, $opticProjectJson, (New-Object System.Text.UTF8Encoding($false)))
& $opticRojoCommand.Source build $opticRoundtripProject --output $opticRoundtripXml
if ($LASTEXITCODE -ne 0) { throw 'Rojo could not read the binary model.' }
$opticDocument = [xml](Get-Content -LiteralPath $opticRoundtripXml -Raw -Encoding UTF8)
$opticRoot = $opticDocument.SelectSingleNode('/roblox/Item')
if ($opticRoot.class -ne 'Script' -or $opticRoot.SelectSingleNode('Properties/string[@name="Name"]').InnerText -ne 'Optic') {
    throw 'The binary model must have one Script root named Optic.'
}
function Assert-OpticSource($Item, [string]$Path) {
    $opticSourceNode = $Item.SelectSingleNode('Properties/*[@name="Source"]')
    if (-not $opticSourceNode -or $opticSourceNode.InnerText -cne (Get-Content -LiteralPath $Path -Raw -Encoding UTF8)) {
        throw ('The binary model source differs from ' + $Path)
    }
}
Assert-OpticSource $opticRoot (Join-Path $opticProjectRoot 'src\init.server.luau')
$opticModules = $opticRoot.SelectNodes('Item[@class="ModuleScript"]')
$opticExpectedModules = @(Get-ChildItem -LiteralPath (Join-Path $opticProjectRoot 'src') -File -Filter '*.luau' | Where-Object { $_.Name -ne 'init.server.luau' })
if ($opticModules.Count -ne $opticExpectedModules.Count -or $opticRoot.SelectNodes('Item').Count -ne $opticModules.Count) {
    throw 'The binary model has missing or unexpected children.'
}
$opticSeen = @{}
foreach ($opticModule in $opticModules) {
    $opticModuleName = $opticModule.SelectSingleNode('Properties/string[@name="Name"]').InnerText
    if ($opticSeen.ContainsKey($opticModuleName)) { throw 'Duplicate module in binary model.' }
    $opticSeen[$opticModuleName] = $true
    Assert-OpticSource $opticModule (Join-Path $opticProjectRoot ('src\' + $opticModuleName + '.luau'))
}
Write-Output ('Verified binary model: Optic Script, exact entry point, ' + $opticModules.Count + ' exact ModuleScript sources.')
