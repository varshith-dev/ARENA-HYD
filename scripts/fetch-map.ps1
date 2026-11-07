$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$bounds = '17.425,78.365,17.469,78.406'
$query = '[out:json][timeout:120];(way["highway"](BOUNDS);way["building"](BOUNDS);way["building:part"](BOUNDS);relation["building"](BOUNDS);relation["type"="building"](BOUNDS);way["natural"="water"](BOUNDS);relation["natural"="water"](BOUNDS);way["landuse"~"grass|forest|recreation_ground"](BOUNDS);way["leisure"="park"](BOUNDS);way["railway"](BOUNDS);node["name"]["place"](BOUNDS);nwr["amenity"="fuel"](BOUNDS);nwr["name"~"Cyber Towers|Cyber Gateway|Mindspace|HITEC City|Raidurg|Trident",i](BOUNDS););out meta geom;'
$query = $query.Replace('BOUNDS',$bounds)
$destination = Join-Path $projectRoot 'game/data/hitec-city.download.json'
$encoded = [Uri]::EscapeDataString($query)
$downloaded = $false
foreach ($endpoint in @('https://overpass.kumi.systems/api/interpreter','https://overpass-api.de/api/interpreter','https://overpass.private.coffee/api/interpreter')) {
    try {
        Invoke-WebRequest -Uri ($endpoint + '?data=' + $encoded) -UserAgent 'ArenaHyderabad/0.1 (local game development)' -OutFile $destination -UseBasicParsing -TimeoutSec 150
        $downloaded = $true
        break
    } catch { Write-Warning $_.Exception.Message }
}
if (!$downloaded) { throw 'All map endpoints failed.' }
$map = Get-Content -LiteralPath $destination -Raw | ConvertFrom-Json
if (!$map.elements -or $map.remark) { throw "Overpass response incomplete: $($map.remark)" }
$current = Join-Path $projectRoot 'game/data/hitec-city.osm.json'
if (Test-Path -LiteralPath $current) {
    $old = Get-Content -LiteralPath $current -Raw | ConvertFrom-Json
    if ($map.elements.Count -lt $old.elements.Count * 0.9) { throw 'Map refresh unexpectedly lost over 10% of the features; retained the existing snapshot.' }
    $archive = Join-Path $projectRoot 'docs/map-before-refresh.json'
    if (!(Test-Path -LiteralPath $archive)) { Copy-Item -LiteralPath $current -Destination $archive }
}
Move-Item -LiteralPath $destination -Destination (Join-Path $projectRoot 'game/data/hitec-city.osm.json') -Force
Write-Output "Downloaded $($map.elements.Count) OSM features."
