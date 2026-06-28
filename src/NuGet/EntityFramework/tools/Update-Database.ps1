# Update-Database.ps1 for SharpDevelop 5.x
param (
    [string]$TargetMigration,
    [switch]$Force,
    [string]$ConfigurationTypeName,
    [string]$ConnectionStringName,
    [string]$ConnectionString,
    [string]$ConnectionProviderName,
    [switch]$Verbose
)

$project = [ICSharpCode.SharpDevelop.Project.ProjectService]::CurrentProject
if (-not $project) {
    Write-Error "No active project found in SharpDevelop."
    return
}

Write-Host "Active project: $($project.Name)"

$assemblyPath = $project.OutputAssemblyFullName
if (-not (Test-Path $assemblyPath)) {
    Write-Error "Output assembly not found at '$assemblyPath'. Please build the project first."
    return
}

$projectDir = $project.Directory
$startUpDirectory = Split-Path -Parent $assemblyPath

$configFilePath = Join-Path $projectDir "App.config"
if (Test-Path (Join-Path $projectDir "Web.config")) {
    $configFilePath = Join-Path $projectDir "Web.config"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$migrateExe = Join-Path $scriptDir "migrate.exe"

if (-not (Test-Path $migrateExe)) {
    # If not found directly in script dir, check bin output directory (for local testing/building)
    $migrateExe = Join-Path (Split-Path $scriptDir -Parent) "bin\Release\migrate.exe"
}

if (-not (Test-Path $migrateExe)) {
    Write-Error "migrate.exe not found."
    return
}

$argsList = @()
$argsList += "`"$assemblyPath`""

if ($ConfigurationTypeName) {
    $argsList += "`"$ConfigurationTypeName`""
}

if ($TargetMigration) {
    $argsList += "/targetMigration:`"$TargetMigration`""
}

if ($startUpDirectory) {
    $argsList += "/startUpDirectory:`"$startUpDirectory`""
}

if (Test-Path $configFilePath) {
    $argsList += "/startUpConfigurationFile:`"$configFilePath`""
}

if ($ConnectionStringName) {
    $argsList += "/connectionStringName:`"$ConnectionStringName`""
}

if ($ConnectionString) {
    $argsList += "/connectionString:`"$ConnectionString`""
}

if ($ConnectionProviderName) {
    $argsList += "/connectionProviderName:`"$ConnectionProviderName`""
}

if ($Force) {
    $argsList += "/force"
}

if ($Verbose) {
    $argsList += "/verbose"
}

Write-Host "Running: $migrateExe $argsList"

# Run migrate.exe out-of-process using Start-Process to avoid locking assemblies inside the IDE AppDomain.
$process = Start-Process -FilePath $migrateExe -ArgumentList $argsList -NoNewWindow -Wait -PassThru

if ($process.ExitCode -ne 0) {
    Write-Error "Database update failed with exit code $($process.ExitCode)"
} else {
    Write-Host "Database update completed successfully."
}
