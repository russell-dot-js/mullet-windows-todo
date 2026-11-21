# Host the shipped Forms window on an STA and operate its real controls.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$exe = Join-Path $PSScriptRoot 'bin/CheckboxLandOffice.exe'
$env:PATH = (Split-Path $exe) + ';' + $env:PATH
[void][Reflection.Assembly]::LoadFrom($exe)
[Windows.Forms.Application]::EnableVisualStyles()
$counter = [LandOffice.Counter]::new($env:MULLET_SQL)
$window = [LandOffice.Desktop]::new($counter)

function Wait-For($description, [scriptblock]$probe) {
    $deadline = (Get-Date).AddSeconds(60)
    do {
        [Windows.Forms.Application]::DoEvents()
        if (& $probe) { return }
        Start-Sleep -Milliseconds 30
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for $description. Counter receipt: $($receipt.Text)"
}
function Control($name) {
    $matches = $window.Controls.Find($name, $true)
    if ($matches.Count -ne 1) { throw "Expected a single control named $name" }
    return $matches[0]
}
try {
    $window.Show()
    $entry = Control 'TitleEntry'
    $receipt = Control 'ReceiptText'
    Wait-For 'the counter to open' { $window.Enabled }
    $title = 'Take minutes at the meeting about fewer meetings ' + [guid]::NewGuid()
    if ($env:MULLET_SCREENSHOT) {
        if ($counter.List().Rows.Count -ne 0) { throw 'Screenshot requires an empty inspection database' }
        $title = 'Buy milk'
    }
    $entry.Text = $title
    (Control 'AddTask').PerformClick()
    Wait-For 'the filing receipt' { $window.Enabled -and $receipt.Text -match '3200 policies' }
    $task = $counter.List().Rows | Where-Object { $_.Title -eq $title }
    if (-not $task -or $task.Closed) { throw 'The new intention did not open' }
    (Control 'Discharge').PerformClick()
    Wait-For 'the discharge receipt' { $window.Enabled -and $receipt.Text -match '#[0-9]+ done' }
    $task = $counter.List().Rows | Where-Object { $_.Title -eq $title }
    if (-not $task.Closed) { throw 'The discharged intention is still open' }
    $deeds = $counter.Receipt($task.TaskId)
    foreach ($act in 'add','done') {
        $deed = @($deeds.Rows | Where-Object { $_.Act -eq $act })
        if ($deed.Count -ne 1 -or $deed[0].Hearings -ne 200 -or
            $deed[0].Contracts -ne 3200 -or $deed[0].SettledCents -ne $deed[0].BilledCents) {
            throw "The $act deed failed its independent reconciliation."
        }
        if ($act -eq 'done') {
            # Reconstruct the die strike without loading the Java program or the CLR assembly.
            [long]$stamp = python "$PSScriptRoot/inspect-engravers.py" --oracle ("close/" + $task.TaskId)
            if ($LASTEXITCODE -or $deed[0].Stamp -ne $stamp) {
                throw "Incorrect stamp. Expected $stamp, received $($deed[0].Stamp) for drawer $($task.TaskId)"
            }
            [long]$previous = 0
            [long]$expected = 0
            for ($hearing = 1; $hearing -le 200; $hearing++) {
                [long]$subtotal = 0
                for ($seat = 1; $seat -le 16; $seat++) {
                    $subtotal += 1 + (($stamp + 31 * $hearing + 17 * $seat + $previous) % (11 + $seat))
                }
                $expected += $subtotal
                $previous = $subtotal
            }
            if ($deed[0].BilledCents -ne $expected) { throw 'The previous hearing lost its vote' }
        }
        Write-Output "$act paid $($deed[0].Payee) for 3,200 policies under JVM stamp $($deed[0].Stamp)."
    }
    if ($env:MULLET_SCREENSHOT) {
        $window.Refresh()
        $bitmap = [Drawing.Bitmap]::new($window.Width, $window.Height)
        try {
            $window.DrawToBitmap($bitmap, [Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height))
            $bitmap.Save($env:MULLET_SCREENSHOT, [Drawing.Imaging.ImageFormat]::Png)
        } finally { $bitmap.Dispose() }
    }
} finally {
    $window.Close()
    $window.Dispose()
}
