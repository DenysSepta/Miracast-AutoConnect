# Contributing

Thanks for helping improve Miracast AutoConnect. Wireless projection depends on the TV model, receiver implementation, Windows version, and Wi-Fi driver, so reproducible details are especially valuable.

## Before opening an issue

1. Read the [README troubleshooting section](README.md#troubleshooting-where-to-start) and [Windows setup guide](docs/windows-setup.md).
2. Identify the stage that fails:
   - the TV receiver does not open;
   - Windows does not discover the TV;
   - the Android UDP trigger is not received;
   - Windows receives the trigger but does not establish projection;
   - projection starts but the TV does not display the desktop.
3. Include relevant environment details:
   - TV model and Android/Google TV version;
   - receiver app and whether it is in waiting mode;
   - Windows version and Wi-Fi adapter/driver version;
   - whether the TV appears in the script's `-Diag` output;
   - relevant log excerpts and the exact command used.

Please redact private IP addresses, device identifiers, usernames, and any other sensitive information before posting logs.

## Pull requests

- Keep changes focused and explain the problem they solve.
- Preserve the distinction between a projection request being issued and a working desktop stream being confirmed.
- Do not claim compatibility with a TV, Windows build, or adapter unless it has actually been tested.
- For documentation changes, verify relative links and commands against the current files.
- Avoid committing personal logs, local configuration, generated build output, or credentials.

## Testing expectations

Test changes on the hardware you have available and document the tested environment. If you cannot test on physical hardware, state that clearly in the pull request. Miracast discovery and connection behavior can differ across devices and drivers.
