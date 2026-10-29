# Windows setup and troubleshooting

## Before you start

1. Confirm Windows supports wireless projection and the Wi-Fi adapter/driver is enabled.
2. Put the TV into its Miracast receiver/waiting screen.
3. Use Windows PowerShell 5.1 (`powershell.exe`), not `pwsh.exe`.
4. Run commands from the repository root and replace `YOUR TV NAME` with the exact display name Windows shows.

## Diagnose device discovery

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\miracast_connect.ps1" -Diag -TargetDeviceName "YOUR TV NAME"
```

If the receiver is not listed, keep the TV on its waiting screen and check the Wi-Fi driver, Windows wireless display support, and whether Windows itself can see the TV as a wireless display.

## Test a single connection

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\miracast_connect.ps1" -TestNow -TargetDeviceName "YOUR TV NAME"
```

This requests a connection through `ProjectionManager` and does not open Win+K. A successful API call does not guarantee the TV is displaying the desktop; verify the screen.

## Install the background listener

Run Windows PowerShell 5.1 as Administrator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\miracast_connect.ps1" -Install -Port 8888 -TargetDeviceName "YOUR TV NAME"
```

The scheduled task is named `MiracastAutoConnect`, runs at logon in the current user's interactive session, and restarts if the listener exits. The firewall rule is scoped to the Private profile and local subnet. If Windows cannot create the firewall rule, create a matching inbound UDP rule manually.

Do not run a second listener on the same UDP port.

## Verify operation

```powershell
Get-ScheduledTask -TaskName "MiracastAutoConnect" | Select-Object TaskName, State
Get-NetUDPEndpoint -LocalPort 8888 -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess
Get-Content ".\scripts\windows\miracast_connect.log" -Tail 40
```

The log is located beside the script. If you copy the script elsewhere, use that folder's log path.

## Change the port or display name

```powershell
.\scripts\windows\miracast_connect.ps1 -Install -Port 8888 -TargetDeviceName "YOUR TV NAME"
```

If changing the listener port, also update `NetworkConfig.kt` in the Android app, rebuild/reinstall the app, and adjust the firewall rule. The Android app sends compatibility packets to port 7250 as well; this does not change Windows' device-discovery behavior.

## Remove the scheduled task and firewall rule

Run PowerShell as Administrator. Replace 8888 if you used a different port.

```powershell
Unregister-ScheduledTask -TaskName "MiracastAutoConnect" -Confirm:$false
Remove-NetFirewallRule -DisplayName "MiracastAutoConnect UDP 8888" -ErrorAction SilentlyContinue
```

## Common problems

- **Port already in use:** stop the existing listener or scheduled task before starting another copy.
- **No UDP trigger in the log:** verify both devices are on a LAN where broadcast is allowed, the firewall rule exists, and Android's trigger port matches `-Port`.
- **TV not discovered:** the TV must be awake and advertising its receiver. Discovery depends on Windows, adapter, and driver support.
- **Trigger received but no connection:** inspect the log for WinRT errors, run `-Diag`, and verify Windows can connect to the TV manually.
- **TV disconnects from normal Wi-Fi while waiting:** some Miracast implementations switch to Wi-Fi Direct. This is TV/driver-specific.
