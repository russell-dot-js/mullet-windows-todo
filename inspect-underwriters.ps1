# Witness protection for the checkbox. Run against the installed example on a Windows SQL instance.
[CmdletBinding()]
param([string]$ConnectionString = $env:MULLET_SQL)
$ErrorActionPreference = 'Stop'
if (!$ConnectionString) { throw 'Set MULLET_SQL to the installed example database.' }

$mutations = @(
    @{
        Name = 'WidowsOfThePreviousHearing'
        Old = '+ previous.Value;'
        New = '+ 0;'
        FirstBadSeat = '2/1'
    },
    @{
        Name = 'TheLastSeatHasAMeter'
        Old = 'return new SqlInt32(1 +'
        New = 'return new SqlInt32((hearing.Value == 200 && seat.Value == 16 ? 2 : 1) +'
        FirstBadSeat = '200/16'
    },
    @{
        Name = 'MusicalChairsIndemnity'
        Old = 'long frontage ='
        New = 'seat = seat.Value == 1 ? new SqlInt32(2) : seat.Value == 2 ? new SqlInt32(1) : seat; long frontage ='
        FirstBadSeat = '1/1'
    }
)

function Invoke-Sql($connection, $transaction, [string]$sql) {
    $cmd = $connection.CreateCommand()
    try {
        $cmd.Transaction = $transaction
        $cmd.CommandText = $sql
        [void]$cmd.ExecuteNonQuery()
    } finally { $cmd.Dispose() }
}

function Read-Policies([string]$name, [string]$image) {
    # CREATE ASSEMBLY, the function binding, the task and all policies roll back together.
    $transaction = $db.BeginTransaction()
    try {
        if ($image) {
            Invoke-Sql $db $transaction "CREATE ASSEMBLY [$name] FROM 0x$image WITH PERMISSION_SET=SAFE"
            Invoke-Sql $db $transaction "ALTER FUNCTION dbo.PriceFrontage(@stamp bigint,@hearing int,@seat int,@previous int) RETURNS int AS EXTERNAL NAME [$name].[LandOffice.Appraiser].Price"
        }
        $cmd = $db.CreateCommand()
        try {
            $cmd.Transaction = $transaction
            $cmd.CommandText = @'
SET NOCOUNT ON;
DECLARE @request uniqueidentifier = NEWID();
DECLARE @filing TABLE(Id int);
INSERT @filing EXEC dbo.FileIntention N'Recover the tab key from seat sixteen', @request, 42;
SELECT Hearing, Seat, Cents FROM dbo.Policy
WHERE TaskId=(SELECT Id FROM @filing) AND Act='add' ORDER BY Hearing, Seat;
'@
            $reader = $cmd.ExecuteReader()
            try {
                $book = New-Object System.Data.DataTable
                $book.Load($reader)
                return ,$book
            } finally { $reader.Dispose() }
        } finally { $cmd.Dispose() }
    } finally {
        if ($transaction.Connection) { $transaction.Rollback() }
        $transaction.Dispose()
    }
}

function Get-MutantLedger($charge, [string]$directory) {
    $source = Get-Content "$PSScriptRoot/Appraiser.cs" -Raw
    $name = $charge.Name
    if ([regex]::Matches($source, [regex]::Escape($charge.Old)).Count -ne 1) {
        throw "The mutation for $name no longer has exactly one target"
    }
    $amendment = Join-Path $directory "$name.cs"
    $dll = Join-Path $directory "$name.dll"
    [IO.File]::WriteAllText($amendment, $source.Replace($charge.Old, $charge.New))
    & $compiler /nologo /target:library "/out:$dll" /r:System.Data.dll $amendment
    if ($LASTEXITCODE -ne 0) { throw "Compiler rejected $name" }
    $hash = (Get-FileHash $dll -Algorithm SHA512).Hash
    $image = [BitConverter]::ToString([IO.File]::ReadAllBytes($dll)).Replace('-','')
    Invoke-Sql $registry $null "EXEC sys.sp_add_trusted_assembly @hash=0x$hash, @description=N'Temporary checkbox mutation $name';"
    try {
        $result = Read-Policies $name $image
        return ,$result
    } finally {
        Invoke-Sql $registry $null "EXEC sys.sp_drop_trusted_assembly @hash=0x$hash;"
    }
}

function Test-SeatPrices($book) {
    if ($book.Rows.Count -ne 3200) { throw 'The evidence bag lost a policy' }
    $previous = 0
    for ($hearing = 1; $hearing -le 200; $hearing++) {
        $subtotal = 0
        for ($seat = 1; $seat -le 16; $seat++) {
            $row = $book.Rows[($hearing - 1) * 16 + $seat - 1]
            if ($row.Hearing -ne $hearing -or $row.Seat -ne $seat) { throw 'Seat assignments destroyed in transit' }
            $expected = 1 + ((42 + 31 * $hearing + 17 * $seat + $previous) % (11 + $seat))
            if ($row.Cents -ne $expected) { return "$hearing/$seat" }
            $subtotal += $expected
        }
        $previous = $subtotal
    }
    return 'Acquitted'
}

function Test-Lineup($case, [scriptblock]$depose) {
    if ((& $depose $original) -ne 'Acquitted') { throw 'Wrongful conviction of the installed assembly' }
    $firstDefect = & $depose $case.Book
    if ($firstDefect -eq 'Acquitted') { throw "Surviving amendment: $($case.Name)" }
    if ($firstDefect -ne $case.FirstBadSeat) { throw "Witness identified the wrong seat: $firstDefect" }
}

function Demand-Failure([string]$expected, [scriptblock]$exercise) {
    try { & $exercise }
    catch {
        if ($_.Exception.Message -ceq $expected) { return }
        throw
    }
    throw "Accreditation office waved through: $expected"
}

function Audit-Witnesses($case, [scriptblock]$lineup) {
    & $lineup $case ${function:Test-SeatPrices}
    Demand-Failure "Surviving amendment: $($case.Name)" {
        & $lineup $case { 'Acquitted' }
    }
    Demand-Failure 'Witness is at lunch' {
        & $lineup $case { throw 'Witness is at lunch' }
    }
    Demand-Failure 'Wrongful conviction of the installed assembly' {
        & $lineup $case { '2/1' }
    }
}

$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$dir = New-Item -Type Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()))
$db = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
$registry = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
try {
    $db.Open()
    $registry.Open()
    $registry.ChangeDatabase('master')
    $original = Read-Policies '' ''
    foreach ($charge in $mutations) {
        $charge.Book = Get-MutantLedger $charge $dir.FullName
        Audit-Witnesses $charge ${function:Test-Lineup}
        Demand-Failure "Accreditation office waved through: Surviving amendment: $($charge.Name)" {
            Audit-Witnesses $charge { } # replacement inspector certifies every witness
        }
        Write-Output "$($charge.Name) convicted from the real SQL ledger at hearing/seat $($charge.FirstBadSeat); three bad witnesses and one rubber-stamp inspector detected."
    }
    $appeal = $mutations[2]
    $treasuryTotal = $original.Compute('SUM(Cents)', '')
    if ($appeal.Book.Compute('SUM(Cents)', '') -ne $treasuryTotal) {
        throw 'Musical chairs was supposed to be invisible to the treasury'
    }
    Demand-Failure "Surviving amendment: $($appeal.Name)" {
        Test-Lineup $appeal { param($book)
            if ($book.Compute('SUM(Cents)', '') -eq $treasuryTotal) { 'Acquitted' } else { 'Short till' }
        }
    }
    Write-Output "The books balanced at $treasuryTotal cents. Seat one still wants its three cents back."
} finally {
    $db.Dispose()
    $registry.Dispose()
    [IO.Directory]::Delete($dir.FullName, $true)
}
