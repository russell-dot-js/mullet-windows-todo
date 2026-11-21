param([string]$Server = '.', [string]$Database = 'MulletTodo')
$ErrorActionPreference = 'Stop'
if ($Database -notmatch '^[A-Za-z][A-Za-z0-9_]{0,63}$') { throw 'Choose a simple database name.' }
$bin = Join-Path $PSScriptRoot bin
$null = New-Item -ItemType Directory -Force $bin
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:library "/out:$bin\Frontage.dll" /r:System.Data.dll "$PSScriptRoot\Appraiser.cs"
if ($LASTEXITCODE) { throw 'Building the SQL CLR appraisal office failed.' }
& $csc /nologo /platform:x64 /target:winexe "/out:$bin\CheckboxLandOffice.exe" /r:System.Data.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll "$PSScriptRoot\Counter.cs" "$PSScriptRoot\Desktop.cs"
if ($LASTEXITCODE) { throw 'Building the desktop client failed.' }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Install Visual Studio Build Tools with the x64 C++ toolset (MASM and linker).' }
$msc = Get-ChildItem "$vs\VC\Tools\MSVC" -Directory | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$tools = Join-Path $msc.FullName 'bin\Hostx64\x64'
& "$tools\ml64.exe" /nologo /c "/Fo$bin\conveyance.obj" "$PSScriptRoot\dies\conveyance.asm"
if ($LASTEXITCODE) { throw 'Assembling the conveyance schedule failed.' }
& "$tools\link.exe" /nologo /dll /noentry /machine:x64 /export:AssessFrontage "/out:$bin\Conveyance.dll" "$bin\conveyance.obj"
if ($LASTEXITCODE) { throw 'Linking the native conveyance office failed.' }
Copy-Item "$PSScriptRoot\mint\Mint.java","$PSScriptRoot\dies\frontage.jasm" $bin -Force

function Invoke-Batch([string]$sql) {
    $cmd = $cn.CreateCommand()
    try {
        $cmd.CommandText = $sql
        $null = $cmd.ExecuteNonQuery()
    } finally { $cmd.Dispose() }
}
$settings = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$settings['Data Source'] = $Server
$settings['Initial Catalog'] = 'master'
$settings['Integrated Security'] = $true
$cn = New-Object System.Data.SqlClient.SqlConnection $settings.ConnectionString
$cn.Open()
try {
    Invoke-Batch "IF (SELECT value_in_use FROM sys.configurations WHERE name='clr enabled')=0 BEGIN EXEC sp_configure 'clr enabled',1; RECONFIGURE; END"
    $dll = Join-Path $bin Frontage.dll
    $digest = (Get-FileHash $dll -Algorithm SHA512).Hash
    $image = [BitConverter]::ToString([IO.File]::ReadAllBytes($dll)).Replace('-','')
    Invoke-Batch "IF NOT EXISTS (SELECT 1 FROM sys.trusted_assemblies WHERE hash=0x$digest) EXEC sys.sp_add_trusted_assembly @hash=0x$digest,@description=N'Mullet checkbox appraisal';"
    Invoke-Batch "IF DB_ID(N'$Database') IS NULL CREATE DATABASE [$Database];"
    $cn.ChangeDatabase($Database)
    Invoke-Batch "IF NOT EXISTS(SELECT 1 FROM sys.assemblies WHERE name='Frontage') EXEC('CREATE ASSEMBLY Frontage FROM 0x$image WITH PERMISSION_SET=SAFE'); ELSE IF NOT EXISTS(SELECT 1 FROM sys.assembly_files WHERE assembly_id=(SELECT assembly_id FROM sys.assemblies WHERE name='Frontage') AND file_id=1 AND content=0x$image) EXEC('ALTER ASSEMBLY Frontage FROM 0x$image WITH PERMISSION_SET=SAFE');"
    Invoke-Batch 'CREATE OR ALTER FUNCTION dbo.PriceFrontage(@stamp bigint,@hearing int,@seat int,@previous int) RETURNS int AS EXTERNAL NAME Frontage.[LandOffice.Appraiser].Price;'
    foreach ($batch in ((Get-Content "$PSScriptRoot\ledger.sql" -Raw) -split '(?im)^GO\s*$')) {
        if ($batch.Trim()) { Invoke-Batch $batch }
    }
    $settings['Initial Catalog'] = $Database
    $settings.ConnectionString | Set-Content "$bin\land-office.connection"
} finally { $cn.Dispose() }
