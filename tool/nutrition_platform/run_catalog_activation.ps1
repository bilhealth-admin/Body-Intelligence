param(
  [Parameter(Mandatory=$true)][string]$CatalogPath,
  [Parameter(Mandatory=$true)][string]$CatalogRoot,
  [Parameter(Mandatory=$true)][string]$CatalogId,
  [Parameter(Mandatory=$true)][string]$Version,
  [int]$SchemaVersion = 1
)
$ErrorActionPreference = "Stop"
$script = @'
from pathlib import Path
from tool.nutrition_platform.catalog_activation_manager import CatalogActivationManager, CatalogManifest
catalog = Path(r"__CATALOG__")
manager = CatalogActivationManager(Path(r"__ROOT__"), supported_schema_version=__SCHEMA__)
manifest = CatalogManifest.from_path(catalog, catalog_id="__ID__", version="__VERSION__", schema_version=__SCHEMA__)
activated = manager.activate(catalog, manifest)
print(activated)
'@
$script = $script.Replace('__CATALOG__', $CatalogPath).Replace('__ROOT__', $CatalogRoot).Replace('__ID__', $CatalogId).Replace('__VERSION__', $Version).Replace('__SCHEMA__', [string]$SchemaVersion)
python -c $script
if ($LASTEXITCODE -ne 0) { throw "Catalog activation failed" }
