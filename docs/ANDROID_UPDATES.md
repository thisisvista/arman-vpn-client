# Android in-app updates

Vista VPN checks the Vista-owned update manifest and can download an Android APK from a release without asking the user to uninstall the installed app.

## Release requirements

- Keep the Android application ID as `com.vista.vpn`.
- Sign every production APK with the same Vista Android upload/release keystore. Android will reject an update signed with a different certificate.
- Keep the keystore and its password in the repository's GitHub Actions secrets (`ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`). Never commit the keystore or print its contents in CI logs.
- Publish the APK under the exact asset name expected by the manifest and release workflow.
- Update `.github/updates.json` so the stable Android version, version code, and asset URL match the release. Do not publish a manifest entry before its APK asset is available.
- Keep the Ed25519 update-signing key (`VISTA_VPN_SIGNING_KEY`) separate from the Android keystore. They serve different purposes.

## What happens on the device

1. The app obtains the Android APK download URL from the update metadata.
2. The native Android updater downloads over HTTPS, follows only HTTPS redirects, limits the file size, and checks that the APK package name matches Vista VPN.
3. It verifies that the candidate version is newer and that its signing certificate matches the installed app.
4. Android's system package installer opens. The user confirms the update there; the previous Vista installation and its app data are retained by Android when the package ID and signing certificate match.

On Android 8 and later, the first installation attempt may open the system setting that allows Vista VPN to install app updates from this source. After granting that permission, return to Vista VPN and retry the update.

## Validation before a public release

- Run the repository CI workflows and resolve all failures.
- Install a release-signed APK on a test device.
- Publish a higher-version APK signed with the same keystore and test the in-app update over both direct and redirected HTTPS downloads.
- Confirm that the updated app launches and that its existing app data remains intact.

This describes the intended release process. A successful source review is not a substitute for a completed CI build and a real-device update test.
