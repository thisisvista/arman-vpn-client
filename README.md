<div align="center">

**🇺🇸 English** &nbsp;/&nbsp; [🇮🇷 فارسی](docs/readme/README_fa.md) &nbsp;/&nbsp; [🇨🇳 简体中文](docs/readme/README_zh.md) &nbsp;/&nbsp; [🇷🇺 Русский](docs/readme/README_ru.md)

</div>

<p align="center"><img src="docs/images/logo.png" width="128" alt="Vista VPN logo"></p>

<h1 align="center">Vista VPN</h1>

<p align="center"><strong>An independent, open-source VPN client.</strong></p>

<p align="center">
  <a href="https://github.com/thisisvista/vista-vpn/releases">GitHub Releases</a> ·
  <a href="LICENSE">GPL-3.0 license</a> ·
  <a href="SECURITY.md">Security</a> ·
  <a href="PRIVACY.md">Privacy</a> ·
  <a href="SUPPORT.md">Support</a>
</p>

> **Unofficial project:** Vista VPN is independently developed. It is not made, owned, sponsored, or endorsed by Mozilla and is not affiliated with Mozilla. Mozilla's services, account requirements, availability, and usage limits remain subject to Mozilla's own terms.

## About

Vista VPN is a client for routing device traffic through the VPN service supported by this project. It uses a Mozilla/Firefox account to access the service. Vista VPN is not itself a VPN server provider; service availability and account limits are controlled by the upstream service.

The repository contains an Android app and desktop application code. Release assets will be listed on the [GitHub Releases page](https://github.com/thisisvista/vista-vpn/releases) when published. A successful CI build is not, by itself, a public release.

## Features

- Connect and disconnect the VPN from the app.
- Choose a server location or use the app's recommended location.
- Configure routing options supported by the core.
- Manage the account and connection settings in the app.
- Android VPN service integration, including a persistent connection notification.
- Open-source code under the GNU GPL version 3.

Feature availability can differ by operating system and by the upstream VPN service.

## Screenshots

Updated screenshots of the current Vista VPN interface will be added after final on-device validation. The repository should not present older interface images as screenshots of the current release.

## Download

**No public release has been published yet.** When the first release is ready, download the appropriate file from:

[**Vista VPN — GitHub Releases**](https://github.com/thisisvista/vista-vpn/releases)

For Android:
- **Universal APK** is intended for broad device compatibility.
- **ARM64-v8a APK** is intended for most modern Android phones and is usually smaller.
- Choose another ABI only if you know your device requires it.

Only install APKs published in this repository's official Releases. Do not treat workflow test artifacts or debug-signed APKs as production releases.

## Install on Android

1. Open the [GitHub Releases page](https://github.com/thisisvista/vista-vpn/releases).
2. Download the APK that matches your device.
3. Open the downloaded file and follow Android's installation prompts. You may need to allow your browser or file manager to install apps from that source.
4. Open Vista VPN and follow the in-app setup and sign-in instructions.
5. Android will ask you to approve the VPN connection before the first connection.

The app's built-in updater is intended for releases signed with the project's persistent release certificate. A debug or locally signed build may not be able to update an installed official release.

## Privacy, troubleshooting, and support

- Read the [Privacy Policy](PRIVACY.md) to understand local storage, account data, VPN traffic handling, backups, logs, and update checks.
- Read [Support](SUPPORT.md) before opening an issue.
- For security concerns, follow [SECURITY.md](SECURITY.md); do not post credentials, tokens, private account data, or unredacted logs in public.
- Review [CHANGELOG.md](CHANGELOG.md) for changes included in each release.

## Building from source

The Android application is built with Flutter and includes a Go-based VPN core plus the Android TUN integration. See [app/README.md](app/README.md) and [core/doc/DEVELOPMENT.md](core/doc/DEVELOPMENT.md) for project-specific build requirements and commands.

A release build requires the project's release-signing configuration. CI test artifacts may be signed with a debug key and are not interchangeable with release-signed APKs.

## License and third-party components

Vista VPN is distributed under the [GNU General Public License v3.0](LICENSE). Third-party components retain their own licenses; see the relevant license files in the source tree.

## Disclaimer

This is an independent, unofficial client. Mozilla did not develop, operate, sponsor, or endorse Vista VPN. Mozilla account credentials and the upstream service are subject to Mozilla's terms and policies. This repository's maintainers are responsible for this application and its support.
