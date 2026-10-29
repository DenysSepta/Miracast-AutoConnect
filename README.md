# Miracast AutoConnect

Automatically open the Miracast receiver on a Xiaomi Android TV and request wireless projection from Windows—without manually opening Win+K on the PC. The original workflow has been tested by the maintainer on their Xiaomi Android TV and Windows PC; other TV models and firmware may behave differently.

## Components

- Android TV app: tries known vendor receiver activities and Android Cast settings intents, then broadcasts a UDP trigger on the local network.
- Windows PowerShell listener: receives the trigger and uses Windows ProjectionManager (WinRT) to discover the configured wireless display and request projection.

> Compatibility varies by TV firmware, receiver app, Windows build, and Wi-Fi driver. The app cannot enable a receiver that is missing or blocked by the TV. Test on your hardware before relying on unattended operation.

## How it works

1. Launch the Android TV app, or map a supported remote key to trigger it using a compatible key-mapping tool.
2. The app attempts to open the receiver screen.
3. It broadcasts UDP trigger messages to the local network. The default Windows trigger port is 8888; compatibility packets are also sent to port 7250.
4. The Windows listener matches the configured display name and requests projection through WinRT. It does not open the Win+K flyout or use UI automation.
5. The listener logs the result. A successful API call or a detected TCP session is not proof that the TV is showing the desktop; verify the actual display.

## Requirements

### Android TV

- Android TV / Google TV with Android 10 (API 29) or later.
- A system or vendor Miracast receiver installed and enabled.
- Android Studio and compatible Android SDK components to build the app.
- TV and PC normally need to be on the same LAN/broadcast domain.

### Windows PC

- Windows 10/11 with wireless projection support and a compatible Wi-Fi adapter/driver.
- Windows PowerShell 5.1 (powershell.exe), not PowerShell 7 (pwsh.exe).
- TV awake and waiting in its Miracast receiver screen.
- For background operation, the listener must run in the logged-in user's interactive session.

## Quick start

### 1. Build the Android TV app

1. Clone this repository and open it in Android Studio.
2. Allow Gradle sync and install any requested Android SDK components.
3. Build the app module and install the APK on your TV.
4. Launch Miracast AutoConnect once to test it.
5. Optional: bind a remote key to the app using your TV's supported key-mapping method. Some devices require enabling the app's Accessibility service. Enable it only if you understand and want the remote-key filtering behavior.

#### Default remote buttons and how to change them

The default key handling is defined in **[`RemoteButtonService.kt`](app/src/main/java/io/github/denyssepta/miracastautoconnect/RemoteButtonService.kt)**. On the maintainer's Xiaomi Android TV remote, the two handled buttons are:

- **Netflix** — Android key code `193` (`KEYCODE_BUTTON_6`)
- **Prime Video** — Android key code `194` (`KEYCODE_BUTTON_7`)

These are the key codes observed on that Xiaomi setup, not universal Netflix/Prime identifiers. Another TV, remote, or firmware may report different codes. There is currently **no in-app button picker**.

To use your own remote buttons:

1. Open `app/src/main/java/io/github/denyssepta/miracastautoconnect/RemoteButtonService.kt` in Android Studio.
2. Find the condition inside `onKeyEvent`:
   
   ```kotlin
   if (event.keyCode == 193 || event.keyCode == 194) {
   ```

3. Replace `193` and `194` with the key codes reported by your remote. For example, if the buttons you want send codes `KEY_A` and `KEY_B`, use their actual numeric codes:
   
   ```kotlin
   if (event.keyCode == 123 || event.keyCode == 124) {
   ```
   
   The numbers `123` and `124` are **illustrative only**; do not use them unless your remote really reports those codes. You can keep one code if you want just one trigger button.
4. To find the real codes, temporarily add `import android.util.Log` and put this at the start of `onKeyEvent`, before the `if`:
   
   ```kotlin
   Log.d("RemoteButtonService", "keyCode=${event.keyCode}, name=${KeyEvent.keyCodeToString(event.keyCode)}, action=${event.action}")
   ```
   
   Enable the app's Accessibility service on the TV, open Android Studio's **Logcat**, filter by `RemoteButtonService`, and press the desired remote buttons. Use the logged numeric `keyCode` values. If no events appear, that TV/firmware may not expose those remote buttons to the Accessibility service.
5. Build the app again and install the new APK on the TV. Remove the temporary logging line/import if you no longer need diagnostics.

If you prefer not to edit/rebuild the app, a compatible key-mapping tool may be able to map a button to launch Miracast AutoConnect. Whether that works depends on the TV and the key mapper.

### 2. Test Windows discovery

Open Windows PowerShell 5.1 from the repository root. Replace YOUR TV NAME with the display name Windows shows for your TV.

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\miracast_connect.ps1" -Diag -TargetDeviceName "YOUR TV NAME"

Keep the TV's receiver screen open. Then test one connection:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\miracast_connect.ps1" -TestNow -TargetDeviceName "YOUR TV NAME"

### 3. Install the background listener

Run Windows PowerShell 5.1 as Administrator:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\miracast_connect.ps1" -Install -Port 8888 -TargetDeviceName "YOUR TV NAME"

This creates/updates a logon scheduled task named MiracastAutoConnect and attempts to add an inbound firewall rule scoped to the Private profile and local subnet. See docs/windows-setup.md for diagnostics, removal, and troubleshooting.

## Configuration

| Setting | Default | Where to change it |
|---|---:|---|
| Windows UDP listener | 8888 | PowerShell -Port argument |
| Target display name | YOUR TV NAME | PowerShell -TargetDeviceName argument |
| Android UDP trigger | 8888 | NetworkConfig.kt |
| Compatibility destination | 7250 | NetworkConfig.kt |
| Windows session-state check | TCP 7236 | Test-MiracastSession in the PowerShell script |

The Android app discovers a LAN IPv4 address dynamically; no personal PC or TV IP address is hard-coded. Broadcast may be blocked by guest Wi-Fi, VLANs, VPNs, or router settings.

## Security and privacy

- The listener accepts small UDP trigger messages from the local network. Do not expose it to the public internet.
- Keep firewall access scoped to the local subnet.
- Logs may contain local device names and LAN addresses. Review them before sharing.
- No cloud service or external account is required.

## Limitations

- Receiver launch intents are vendor-specific and may not work on every Android TV.
- UDP broadcast does not cross most routers or VLANs.
- Windows wireless projection requires compatible hardware, drivers, and OS support.
- A projection request does not guarantee that video is actually displayed.

## License

This project is licensed under the [MIT License](LICENSE). See the `LICENSE` file for the full license text.
