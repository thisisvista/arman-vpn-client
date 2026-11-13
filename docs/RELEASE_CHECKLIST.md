# GitHub Release Checklist

This repository's release workflow publishes a GitHub Release automatically when a matching version tag is pushed. Do not create a public release from a workflow test artifact.

## 1. Before preparing a release

- [ ] Finish and review the implementation changes.
- [ ] Keep pull requests in draft until the changes are ready.
- [ ] Merge stacked pull requests in dependency order. In the current development stack, PR #1 targets `main` and PR #2 targets PR #1's branch; PR #1 must be completed before PR #2 can land on `main`.
- [ ] Confirm the default branch contains the exact code and documentation intended for release.
- [ ] Run CI successfully and install the release candidate on real devices.
- [ ] Test sign-in, connection/disconnection, server selection, routing, app restart, notification behavior, update flow, and recovery from network changes.
- [ ] Review the privacy policy, security instructions, support guide, screenshots, and third-party license notices.
- [ ] Decide whether the remembered-password encryption key should remain beside account data or be protected by a platform keystore; review Android backup behavior because the current rules may back up both the encrypted password and its key.

## 2. Version and update metadata

- [ ] Set `app/pubspec.yaml` to the intended version, for example `1.0.20+141`. The part before `+` is the public semantic version; the number after `+` is the Android build number.
- [ ] Create a tag that exactly matches the semantic version: `v1.0.20`.
- [ ] Update `.github/updates.json` on the **default branch** only when the corresponding release is ready to publish. The app reads update metadata from `main`; advertising a version before its release assets exist can make update checks fail.
- [ ] Set the version only for platforms that will actually receive assets in this release.

## 3. Release signing secrets

The GitHub Actions release workflow requires these repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64`: the persistent Android release keystore encoded as Base64.
- `ANDROID_KEYSTORE_PASSWORD`: the keystore/key password expected by the workflow.
- `VISTA_VPN_SIGNING_KEY`: the signing key used for the release checksum manifest and signed core/service updates.

The Android workflow verifies the signing certificate against the SHA-256 fingerprint embedded in `.github/workflows/build.yml`. The keystore must match that expected certificate. Never generate a replacement keystore casually: users need the same signing certificate to install updates over an existing official build. Keep all signing secrets private and maintain a secure offline backup.

If a required secret is missing or does not match, the release workflow will fail. Do not work around a signing failure by publishing a debug-signed APK.

## 4. Publish

- [ ] Confirm the README download table contains the exact asset names produced by the workflow. `scripts/release-notes.sh` extracts this table to generate release notes.
- [ ] Push the matching tag after the intended commit is on the default branch.
- [ ] Wait for every required build and test job to complete successfully.
- [ ] Confirm the workflow created the GitHub Release and attached all expected platform assets.
- [ ] Verify `SHA256SUMS.txt` and its signature are present.
- [ ] Download the Android APK and verify its signature and package identity before announcing the release.
- [ ] Test the published download links from a clean browser/device.

## 5. After publishing

- [ ] Update `CHANGELOG.md` with the release version, date, and user-facing changes.
- [ ] Replace the README's pre-release notice with the published release instructions.
- [ ] Confirm `.github/updates.json` advertises the published version on `main`.
- [ ] Confirm the app's About > Update flow can discover and install the new version.
- [ ] Keep the previous release available so users can recover if needed.

## Current repository-specific blockers

- No public GitHub Release exists yet.
- The current app version is `1.0.19+140`; the matching tag would be `v1.0.19`.
- The current `.github/updates.json` still advertises `1.0.18` for all platforms. Do not change it until the release is ready and the update assets are available.
- Confirm that all three signing secrets exist and that the Android keystore matches the certificate fingerprint expected by the workflow.
- The repository's GitHub description and homepage still contain old project branding/contact information; update them in **Settings → General** before public launch.
