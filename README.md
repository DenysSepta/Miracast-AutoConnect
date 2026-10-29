# Miracast AutoConnect for Android TV and Windows

**Automate a Miracast / Wi-Fi display connection from Android TV to a Windows PC—without opening the Windows `Win+K` flyout or relying on UI automation.**

Miracast AutoConnect combines a small Android TV app with a Windows PowerShell listener. The app opens the TV's available Miracast receiver and sends a local-network trigger; the Windows listener uses the Windows Runtime (`ProjectionManager`) to discover the configured wireless display and request projection.

The original end-to-end workflow was tested by the maintainer with a **Xiaomi Android TV and a Windows PC**. Compatibility with other TVs, receiver apps, Windows builds, and Wi-Fi drivers has not been independently verified. Miracast behavior can vary significantly between devices.

## Features

- Android TV app to launch available Miracast receiver/settings activities.
- Windows 10/11 listener that requests projection through WinRT.
- UDP trigger on the local network; no fixed PC IP address in the Android app.
- Optional logon scheduled task for background listening.
- Remote-button trigger support through Android Accessibility, with device-specific key codes.
- Diagnostics and logs for troubleshooting difficult wireless-display discovery and connection failures.
- No cloud service or external account required.

## How the connection flow works

1. Put the TV in its Miracast receiver/waiting mode.
2. Launch Miracast AutoConnect on Android TV, or use a supported remote-button mapping.
3. The Android app attempts to open the receiver and broadcasts a trigger message on the local network.
4. The Windows listener receives the trigger on UDP port `8888`.
5. Windows `ProjectionManager` searches for the configured TV display name and requests projection.
6. Check the TV itself to confirm that the desktop is actually visible. A successful API call or a detected TCP session alone does **not** prove that video is being displayed.

This project does not open the `Win+K` flyout and does not automate keyboard/mouse interaction with Windows UI.

## Requirements and compatibility

### Android TV

- Android TV / Google TV running Android 10 (API 29) or later.
- A compatible Miracast receiver installed and enabled by the TV firmware.
- Android Studio and the Android SDK components required by the project to build the APK.
- The TV and PC should normally be on the same local network/broadcast domain.

### Windows PC

- Windows 10 or Windows 11 with wireless projection support.
- A compatible Wi-Fi adapter and driver.
- **Windows PowerShell 5.1** (`powershell.exe`), not PowerShell 7 (`pwsh.exe`).
- The TV awake and waiting in its Miracast receiver screen during discovery/connection.
- For background mode, the listener must run in the logged-in user's interactive session.

### Tested vs. unverified

- **Tested by the maintainer:** original workflow on a Xiaomi Android TV and a Windows PC.
- **Not guaranteed:** other Xiaomi models, other Android TV brands, third-party receiver apps, different Windows versions/drivers, mesh/guest networks, or VLAN-separated devices.

The app cannot enable a Miracast receiver that is missing, disabled, or blocked by the TV. A successful trigger is only the start of the workflow; device discovery and the actual wireless projection session can still fail.

## Quick start

### 1. Build and install the Android TV app

1. Clone this repository and open it in Android Studio.
2. Allow Gradle sync and install any Android SDK components requested by the IDE.
3. Build the `app` module and install the resulting APK on the TV.
4. Launch **Miracast AutoConnect** once to test receiver launch and network-trigger behavior.
5. If you want to use a remote button, see [Default remote buttons and customization](#remote-control-buttons).

The repository contains the Android app source; this README does not provide a prebuilt APK release.

### 2. Check whether Windows can discover the TV

Open **Windows PowerShell 5.1** from the repository root. Replace `YOUR TV NAME` with the exact display name Windows shows for the TV:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\miracast_connect.ps1" -Diag -TargetDeviceName "YOUR TV NAME"
```

Keep the TV on its Miracast waiting screen. The diagnostic command lists the projection devices returned by Windows. If the TV is not listed here, investigate Windows wireless-display support, the TV receiver state, and the Wi-Fi adapter/driver before troubleshooting the Android trigger.

### 3. Request one test connection

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\miracast_connect.ps1" -TestNow -TargetDeviceName "YOUR TV NAME"
```

Verify the TV screen. A command result alone does not confirm that the desktop is visible.

### 4. Install the background Windows listener (optional)

Run Windows PowerShell 5.1 as Administrator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\miracast_connect.ps1" -Install -Port 8888 -TargetDeviceName "YOUR TV NAME"
```

This creates or updates a logon scheduled task named `MiracastAutoConnect` and attempts to add an inbound firewall rule scoped to the Private profile and local subnet. The task is intended to run in the logged-in user's interactive session. Do not start a second listener on the same UDP port.

For task verification, removal instructions, and more diagnostics, see [Windows setup and troubleshooting](docs/windows-setup.md).

## Remote-control buttons

The current Accessibility service is implemented in [`RemoteButtonService.kt`](app/src/main/java/io/github/denyssepta/miracastautoconnect/RemoteButtonService.kt). On the maintainer's Xiaomi Android TV remote, the default handled buttons are:

- **Netflix** — Android key code `193`
- **Prime Video** — Android key code `194`

These are the codes observed on that particular Xiaomi setup, not universal identifiers for those buttons. Other remotes or firmware may report different codes. The app currently has **no in-app button picker**.

To change the buttons, edit the `event.keyCode` condition in `RemoteButtonService.kt`, identify the numeric key codes your remote actually sends, then rebuild and reinstall the APK. The README's [remote-button instructions](#default-remote-buttons-and-how-to-change-them) in earlier versions may be useful; for current code, follow the steps in the linked Kotlin file and use Android Studio Logcat to inspect key events. A compatible key-mapping app may also be able to launch Miracast AutoConnect, depending on the TV.

## Configuration and network protocol

| Setting | Default | Where to change it |
|---|---:|---|
| Windows UDP listener | `8888` | PowerShell `-Port` argument |
| Windows target display name | `YOUR TV NAME` | PowerShell `-TargetDeviceName` argument |
| Android UDP trigger | `8888` | `NetworkConfig.kt` |
| Compatibility destination | `7250` | `NetworkConfig.kt` |
| Windows session-state signal | TCP `7236` | `Test-MiracastSession` in the PowerShell script |

The Android app discovers an active LAN IPv4 address dynamically. By default, it sends UDP broadcasts to `255.255.255.255` and a discovered subnet broadcast address. Trigger messages include `MS-MICE_CONNECT_REQ` and `CONNECT_MIRACAST`.

For message formats, port details, and network limitations, see [Network protocol](docs/network-protocol.md).

## Troubleshooting: where to start

**TV not found by Windows?**
- Put the TV on its Miracast receiver/waiting screen and keep it awake.
- Run the `-Diag` command above and confirm that Windows lists the TV.
- Confirm that Windows wireless projection and the Wi-Fi driver work on this PC.

**The Android trigger does not reach Windows?**
- Confirm the listener is bound to UDP port `8888` and the scheduled task is running.
- Confirm Android and Windows are on a network that allows local broadcast traffic.
- Check the Windows firewall rule and ensure the Android trigger port matches the listener's `-Port` value.
- Guest Wi-Fi isolation, VLANs, VPNs, and router filtering can block broadcast packets.

**The trigger is logged, but projection does not start?**
- Check the exact TV display name passed to `-TargetDeviceName`.
- Run `-TestNow` while the TV is waiting for Miracast.
- Inspect the listener log for WinRT errors and whether a TCP session on port `7236` was detected.
- If Windows cannot connect to the TV manually, resolve that Windows/TV/driver issue first.

**The TV disconnects from normal Wi-Fi while waiting?**
Some Miracast implementations switch to Wi-Fi Direct. Behavior depends on the TV, adapter, and driver; it is not necessarily a failure of the UDP trigger itself.

Detailed commands and scheduled-task troubleshooting are in [`docs/windows-setup.md`](docs/windows-setup.md).

## Security and privacy

- The listener accepts small UDP trigger messages from the local network. **Do not expose its ports to the public internet or forward them from your router.**
- Keep firewall access scoped to the local subnet.
- Logs may contain local device names and LAN addresses; review them before sharing.
- The project does not require a cloud service or external account.

## Contributing and bug reports

Connection issues are hardware- and driver-dependent, so useful diagnostics are more helpful than a report that says only “it does not work.” Before opening an issue, check the troubleshooting guide and include, where possible:

- TV model, Android/Google TV version, and receiver app/mode.
- Windows version and Wi-Fi adapter/driver.
- Whether Windows lists the TV in the `-Diag` output.
- Whether the UDP trigger appears in the listener log.
- The relevant log lines and the exact step that fails.

Remove private IP addresses, device identifiers, or other sensitive details before posting logs publicly. See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and issue-reporting guidance.

## License

Miracast AutoConnect is licensed under the [MIT License](LICENSE).
