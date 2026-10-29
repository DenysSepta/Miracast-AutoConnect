<#
.SYNOPSIS
    Listen for a UDP trigger and request wireless projection via Windows ProjectionManager.

.DESCRIPTION
    Requires Windows PowerShell 5.1 (powershell.exe) in the logged-in user's interactive session.
    Does not open the Win+K flyout and does not use UI automation.
    Log: miracast_connect.log beside this script.
#>
[CmdletBinding()]
param(
    [ValidateRange(1,65535)]
    [int]$Port = 8888,
    [string]$TargetDeviceName = 'YOUR TV NAME',
    [ValidateRange(1,120)]
    [int]$SearchTimeoutSec = 20,
    [switch]$TestNow,
    [switch]$Diag,
    [switch]$Install
)

$CooldownSeconds = 3
$TaskName = 'MiracastAutoConnect'
$LogFile = Join-Path $PSScriptRoot 'miracast_connect.log'

function Write-Log([string]$Message, [string]$Color = 'Gray') {
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Message
    try {
        if ((Test-Path -LiteralPath $LogFile) -and ((Get-Item -LiteralPath $LogFile).Length -gt 1MB)) {
            Remove-Item -LiteralPath $LogFile -Force
        }
        Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    } catch {}
    Write-Host $line -ForegroundColor $Color
}

function Set-FirewallRule {
    $ruleName = "MiracastAutoConnect UDP $Port"
    try {
        if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) { return }
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol UDP -LocalPort $Port -Action Allow -Profile Private -RemoteAddress LocalSubnet -ErrorAction Stop | Out-Null
        Write-Log "Created local-subnet firewall rule: $ruleName" Green
    } catch {
        Write-Log "Could not create firewall rule. Run once as Administrator. $($_.Exception.Message)" Yellow
    }
}

function Initialize-ProjectionRuntime {
    if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) {
        throw 'Use Windows PowerShell 5.1 (powershell.exe), not PowerShell 7 (pwsh.exe).'
    }
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Devices.Enumeration.DeviceInformation,Windows.Devices.Enumeration,ContentType=WindowsRuntime]
    $null = [Windows.Devices.Enumeration.DeviceInformationCollection,Windows.Devices.Enumeration,ContentType=WindowsRuntime]
    $null = [Windows.UI.ViewManagement.ProjectionManager,Windows.UI.ViewManagement,ContentType=WindowsRuntime]

    $script:WinRtExtensions = [System.WindowsRuntimeSystemExtensions]
    $script:AsTaskGeneric = $script:WinRtExtensions.GetMethods() |
        Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } |
        Select-Object -First 1
    $script:AsTaskAction = $script:WinRtExtensions.GetMethods() |
        Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } |
        Select-Object -First 1
    if (-not $script:AsTaskGeneric -or -not $script:AsTaskAction) {
        throw 'Could not resolve WinRT AsTask overloads.'
    }
}

function Wait-WinRtOperation($Operation, [Type]$ResultType) {
    $task = $script:AsTaskGeneric.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $task.GetAwaiter().GetResult()
}
function Wait-WinRtAction($Operation) {
    $task = $script:AsTaskAction.Invoke($null, @($Operation))
    $task.GetAwaiter().GetResult()
}
function Test-MiracastSession {
    return [bool](Get-NetTCPConnection -LocalPort 7236 -State Established -ErrorAction SilentlyContinue | Select-Object -First 1)
}
function Get-ProjectionDevices {
    $selector = [Windows.UI.ViewManagement.ProjectionManager]::GetDeviceSelector()
    Wait-WinRtOperation ([Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($selector)) ([Windows.Devices.Enumeration.DeviceInformationCollection])
}

function Invoke-TargetedConnect([string]$DeviceName) {
    try { Initialize-ProjectionRuntime }
    catch {
        Write-Log "WinRT initialization failed: $($_.Exception.GetBaseException().Message)" Red
        return $false
    }

    if (Test-MiracastSession) {
        Write-Log 'A Miracast TCP session on local port 7236 is already established.' Green
        return $true
    }

    $deadline = (Get-Date).AddSeconds([Math]::Max(1, $SearchTimeoutSec))
    $tv = $null
    $attempt = 0
    while ((Get-Date) -lt $deadline -and -not $tv) {
        $attempt++
        try {
            $devices = Get-ProjectionDevices
            $tv = $devices | Where-Object { $_.Name -eq $DeviceName } | Select-Object -First 1
            if (-not $tv) {
                $tv = $devices | Where-Object {
                    $_.Name -and $_.Name.IndexOf($DeviceName, [StringComparison]::OrdinalIgnoreCase) -ge 0
                } | Select-Object -First 1
            }
        } catch {
            Write-Log "Device discovery attempt $attempt failed: $($_.Exception.GetBaseException().Message)" DarkYellow
        }
        if (-not $tv) { Start-Sleep -Seconds 1 }
    }

    if (-not $tv) {
        Write-Log "ProjectionManager did not discover '$DeviceName'. Ensure the TV is awake and waiting for Miracast." Yellow
        return $false
    }
    Write-Log "Projection device found: Name='$($tv.Name)'." Green

    try {
        Wait-WinRtAction ([Windows.UI.ViewManagement.ProjectionManager]::StartProjectingAsync(0, 0, $tv))
        Write-Log 'StartProjectingAsync completed without a WinRT exception.' Cyan
    } catch {
        Write-Log "StartProjectingAsync reported: $($_.Exception.GetBaseException().Message). Checking session state anyway." Yellow
    }

    for ($i = 0; $i -lt 20; $i++) {
        if (Test-MiracastSession) {
            Write-Log 'Miracast session detected on local TCP port 7236.' Green
            return $true
        }
        Start-Sleep -Seconds 1
    }
    Write-Log 'Projection request was issued, but a session was not confirmed within 20 seconds.' Yellow
    return $false
}

if ($Install) {
    if ($TargetDeviceName -eq 'YOUR TV NAME') {
        throw 'Pass -TargetDeviceName with the display name Windows shows for your TV.'
    }
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $taskArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Port $Port -TargetDeviceName `"$TargetDeviceName`""
    $action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $taskArgs
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
    $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Set-FirewallRule
    Start-ScheduledTask -TaskName $TaskName
    Write-Log "Scheduled task '$TaskName' installed/updated for $currentUser." Green
    exit 0
}

if ($Diag) {
    try {
        Initialize-ProjectionRuntime
        $devices = Get-ProjectionDevices
        Write-Log "ProjectionManager returned $($devices.Count) device(s)." Cyan
        foreach ($device in $devices) { Write-Log "Device: Name='$($device.Name)' Id='$($device.Id)'." Gray }
    } catch {
        Write-Log "Diagnostic failed: $($_.Exception.GetBaseException().Message)" Red
        exit 1
    }
    exit 0
}

if ($TestNow) {
    if ($TargetDeviceName -eq 'YOUR TV NAME') {
        throw 'Pass -TargetDeviceName with the display name Windows shows for your TV.'
    }
    $ok = Invoke-TargetedConnect $TargetDeviceName
    Write-Log "TestNow result: $ok"
    if ($ok) { exit 0 } else { exit 3 }
}

Set-FirewallRule
try {
    $UdpClient = New-Object System.Net.Sockets.UdpClient($Port)
} catch {
    Write-Log "Failed to bind UDP $Port (possibly already running): $($_.Exception.Message)" Red
    exit 1
}

Write-Log "Listening on UDP $Port. Target device: '$TargetDeviceName'. No Win+K/UI automation." Green
$signalPattern = '^(?:MS-MICE_CONNECT_REQ|CONNECT_MIRACAST)(?::(?<ip>[^:\s]+):(?<port>\d+))?$'
$lastTrigger = [DateTime]::MinValue

try {
    while ($true) {
        $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $bytes = $UdpClient.Receive([ref]$remote)
        $message = [System.Text.Encoding]::ASCII.GetString($bytes).Trim()
        $now = Get-Date

        if (($now - $lastTrigger).TotalSeconds -lt $CooldownSeconds) {
            Write-Log "Cooldown: ignored trigger from $($remote.Address)." DarkGray
        } elseif ($message -match $signalPattern) {
            $lastTrigger = $now
            Write-Log "Received recognized trigger '$message' from $($remote.Address)." Cyan
            $ok = Invoke-TargetedConnect $TargetDeviceName
            if ($ok) { Write-Log "Projection request/session succeeded for '$TargetDeviceName'." Green }
            else { Write-Log "Projection attempt for '$TargetDeviceName' was not confirmed." Yellow }
            $lastTrigger = Get-Date
        } else {
            Write-Log "Ignored unknown UDP payload from $($remote.Address)." DarkYellow
        }
        while ($UdpClient.Available -gt 0) { [void]$UdpClient.Receive([ref]$remote) }
    }
} catch {
    Write-Log "Listener stopped: $($_.Exception.Message)" Red
} finally {
    if ($UdpClient) { $UdpClient.Dispose() }
}
