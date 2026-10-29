# Network protocol

The Android app sends short UDP datagrams to broadcast addresses on the local network. It does not need a fixed PC IP address.

## Default messages and ports

| Purpose | Default port | Message |
|---|---:|---|
| Windows listener trigger | 8888 | `MS-MICE_CONNECT_REQ:<android-ip>:7250` |
| Compatibility trigger | 8888 | `CONNECT_MIRACAST:<android-ip>:7250` |
| Compatibility destination | 7250 | The Android app also sends trigger messages here |

The Windows listener accepts `MS-MICE_CONNECT_REQ` and `CONNECT_MIRACAST`, with or without the endpoint suffix. The endpoint in the message is diagnostic metadata; the Windows script uses Windows projection device discovery and the configured TV display name.

Port **7236** is used as a Windows session-state signal when checking for an established local Miracast connection. It is not the UDP trigger port.

## Broadcast behavior

The Android app attempts to send to both `255.255.255.255` and a subnet broadcast address discovered from active non-loopback network interfaces. Android and Windows generally need to share a broadcast domain.

Guest Wi-Fi isolation, VLANs, VPNs, router filtering, and some Android TV network stacks can prevent delivery. Do not forward these ports from the internet to your PC.

## Customization

- Windows listener: use `-Port <number>`.
- Android app: edit `NetworkConfig.kt`, rebuild, and reinstall.
- Ensure the Windows listener port and Android `UDP_TRIGGER_PORT` match.
- The compatibility destination defaults to 7250; changing it is optional and does not change Windows device discovery.
