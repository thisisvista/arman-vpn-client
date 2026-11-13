# Privacy Policy

**Last reviewed:** 13 November 2026  
**Applies to:** Vista VPN source in this repository and builds made from it.

This document describes data handling visible in the current source code. It is a technical summary, not a guarantee about the independent upstream VPN service or a substitute for legal review. Data flows may change in later versions; this policy must be reviewed whenever the app or its dependencies change.

## 1. Who operates the service

Vista VPN is an independently maintained client. The project maintainers do not operate the upstream VPN network. The app uses a Mozilla/Firefox account and connects to the upstream service supported by the core. Mozilla and its infrastructure providers process information under their own terms and privacy notices, including the [Mozilla Privacy Policy](https://www.mozilla.org/privacy/).

## 2. Account information

When you sign in, account credentials are sent to Mozilla Account authentication endpoints so the upstream service can authenticate you. The app stores account-related information locally, which can include:

- Your account email address and an internal account identifier.
- OAuth access and refresh tokens used to keep the account signed in.
- The account password, if the remember-password feature is used, so the app can reauthenticate after a token is revoked.
- Account/device registration identifiers.
- Account status and the latest usage/quota information returned by the upstream service.

The core stores account records and credentials in the app's data directory. It creates private directories and restricts credential-file permissions where the operating system supports POSIX file permissions. OAuth tokens are stored in the local credentials file and are not separately encrypted by the app. A remembered account password is encrypted with AES-256-GCM; however, the encryption key is stored in the same account-data directory (in `secret.key`). This protects the password field from casual inspection of the credentials file, but it does not protect the password from someone who obtains the complete data directory or a backup containing both the encrypted password and its key. Treat the entire app data folder and its backups as sensitive.

## 3. VPN traffic and DNS

When the VPN is connected, traffic selected by the app's routing rules is carried through the upstream VPN proxy. To provide that service, the upstream provider and the destination services may process network information such as your public IP address, destination IP addresses or hostnames, connection metadata, and traffic data.

DNS queries handled by the VPN are sent through the proxy using DNS over HTTPS. Vista VPN does not operate the upstream DNS or VPN infrastructure and cannot determine or promise the upstream provider's retention practices. Review the upstream provider's privacy terms before using the service.

The app's routing settings can determine which apps or destinations use the VPN. Traffic deliberately excluded by those rules may connect directly through your normal network provider.

## 4. Information stored on your device

Depending on the features you use, local app data can include:

- Account records and authentication tokens.
- VPN configuration, server and routing preferences.
- App preferences such as language and theme.
- Cached update information and announcements.
- Diagnostic logs.

The app stores its Android core data in its private application storage. Removing an account from the app removes its locally stored account entry and credentials; it does not delete the underlying Mozilla Account.

## 5. Android backup

The Android manifest currently allows system backup. The repository's backup rules exclude diagnostic logs, routing-list/cache data, selected runtime files, and the local API token. Account data, the credentials file, the remembered-password encryption key (`secret.key`), and settings are not excluded by those rules and may therefore be included together in Android cloud backup or device-to-device transfer, subject to the device's Android version and the backup settings/provider you use. Because the password-encryption key is stored beside the encrypted password, a backup containing both should be treated as sensitive.

If you do not want account information included in device backup, review and disable the relevant Android backup options on your device. Backup storage and retention are controlled by Android and your device or cloud-backup provider, not by Vista VPN.

## 6. Diagnostic logs

The core writes diagnostic logs locally. Log files are rotated by day and normally retained for up to seven days, with a per-day size limit. Standard logging masks part of an account email address and redacts some destination details. Detailed/verbose logging can include more identifying information, including full account email addresses and connection destinations. Network addresses and error details may also appear.

Logs are not required to be sent to the project maintainers for the app to work. If you choose to share logs for support, review and redact them first. Never post passwords, OAuth tokens, account backups, or private configuration files in a public issue.

## 7. Updates and announcements

The app checks for update metadata and announcements using project-hosted files and GitHub release information. The code may request metadata from:

- `raw.githubusercontent.com`
- `cdn.jsdelivr.net`
- `api.github.com` and GitHub release download URLs

These services receive ordinary request metadata such as your IP address and request headers. The app's update User-Agent includes the app version. When available, the app can use its local VPN proxy for these requests; otherwise, requests use the device's network connection. Downloaded update files come from GitHub Releases.

## 8. Analytics and advertising

This repository's documented app behavior does not require an advertising account or an in-app advertising service to provide the VPN functionality. This statement does not cover data processing by Mozilla, destination websites, network operators, Android, GitHub, or other third-party services.

## 9. Your choices

- You can disconnect the VPN at any time from the app or Android's VPN controls.
- You can manage or remove saved accounts within the app.
- You can disable detailed/verbose logging and avoid sharing diagnostic files.
- You can review Android backup settings if you do not want account data included in device backups.
- You can stop update checks by not using the app; update availability and security fixes may then be missed.

Uninstalling the app removes its local private app data according to Android's behavior, but does not delete your Mozilla Account or copies already held by backup providers.

## 10. Changes and contact

This policy may be updated when the app's data handling changes. The current version is maintained in this repository. For privacy questions, use the contact options on the [project maintainer's GitHub profile](https://github.com/thisisvista). Do not include account passwords, tokens, or private data in public issues.
