# Add-Migration.ps1 for SharpDevelop 5.x
param (
    [parameter(Position = 0, Mandatory = $true)]
    [string] $Name,
    [switch] $Force,
    [string] $ConfigurationTypeName,
    [string] $ConnectionStringName,
    [string] $ConnectionString,
    [string] $ConnectionProviderName,
    [switch] $IgnoreChanges
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

# Load EntityFramework assembly to resolve ToolingFacade
[System.Reflection.Assembly]::LoadFrom($assemblyPath) | Out-Null
$efAssemblyPath = Join-Path $startUpDirectory "EntityFramework.dll"
if (-not (Test-Path $efAssemblyPath)) {
    Write-Error "EntityFramework.dll not found in startup directory: $startUpDirectory"
    return
}
[System.Reflection.Assembly]::LoadFrom($efAssemblyPath) | Out-Null

$connectionStringInfo = $null
if ($ConnectionStringName) {
    $connectionStringInfo = New-Object System.Data.Entity.Infrastructure.DbConnectionInfo $ConnectionStringName
} elseif ($ConnectionString) {
    $connectionStringInfo = New-Object System.Data.Entity.Infrastructure.DbConnectionInfo $ConnectionString, $ConnectionProviderName
}

# Instantiate ToolingFacade
$facade = New-Object System.Data.Entity.Migrations.Design.ToolingFacade (
    $project.Name,           # migrationsAssemblyName
    $project.Name,           # contextAssemblyName
    $ConfigurationTypeName,  # configurationTypeName
    $startUpDirectory,       # workingDirectory
    $configFilePath,         # configurationFilePath
    $startUpDirectory,       # dataDirectory
    $connectionStringInfo    # connectionStringInfo
)

$facade.LogInfoDelegate = [Action[string]]{ param($msg) Write-Host $msg }
$facade.LogWarningDelegate = [Action[string]]{ param($msg) Write-Warning $msg }
$facade.LogVerboseDelegate = [Action[string]]{ param($msg) Write-Verbose $msg }

$language = "cs"
if ($project.FileName -like "*.vbproj") {
    $language = "vb"
}

$rootNamespace = $project.RootNamespace
if (-not $rootNamespace) {
    $rootNamespace = $project.Name
}

try {
    Write-Host "Scaffolding migration '$Name'..."
    $scaffoldedMigration = $facade.Scaffold($Name, $language, $rootNamespace, $IgnoreChanges.IsPresent)

    # Ensure Migrations directory exists
    $migrationsDir = Join-Path $projectDir "Migrations"
    if (-not (Test-Path $migrationsDir)) {
        New-Item -ItemType Directory -Path $migrationsDir -Force | Out-Null
    }

    # Absolute paths for new files
    $userCodePath = Join-Path $migrationsDir "$($scaffoldedMigration.MigrationId).$language"
    $designerCodePath = Join-Path $migrationsDir "$($scaffoldedMigration.MigrationId).Designer.$language"
    $resxPath = Join-Path $migrationsDir "$($scaffoldedMigration.MigrationId).resx"

    # Write files to disk
    [System.IO.File]::WriteAllText($userCodePath, $scaffoldedMigration.UserCode)
    [System.IO.File]::WriteAllText($designerCodePath, $scaffoldedMigration.DesignerCode)

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $writer = New-Object System.Resources.ResXResourceWriter $resxPath
    foreach ($key in $scaffoldedMigration.Resources.Keys) {
        $writer.AddResource($key, $scaffoldedMigration.Resources[$key])
    }
    $writer.Close()

    # Helper function to add items to project
    function Add-FileToProject($project, $filePath, $itemType, $dependentUpon = $null) {
        $itemTypeObj = New-Object ICSharpCode.SharpDevelop.Project.ItemType $itemType
        $projectItem = New-Object ICSharpCode.SharpDevelop.Project.FileProjectItem $project, $itemTypeObj, $filePath
        if ($dependentUpon) {
            $projectItem.SetMetadata("DependentUpon", $dependentUpon)
        }
        [ICSharpCode.SharpDevelop.Project.ProjectService]::AddProjectItem($project, $projectItem)
    }

    $userCodeName = Split-Path -Leaf $userCodePath
    Add-FileToProject $project $userCodePath "Compile"
    Add-FileToProject $project $designerCodePath "Compile" $userCodeName
    Add-FileToProject $project $resxPath "EmbeddedResource" $userCodeName

    $project.Save()
    Write-Host "Scaffolded migration file added to project: $userCodeName"
}
finally {
    $facade.Dispose()
}
