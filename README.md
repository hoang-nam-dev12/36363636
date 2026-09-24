<p align="center">
  <img src="docs/images/app-icon.png" width="132" alt="Duy Mạnh Store app icon">
</p>

<h1 align="center">Duy Mạnh Store</h1>

<p align="center">
  A native iOS workspace for app-container files, portable .3105 patches, limited cleanup, and PosterBoard wallpaper packages.
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-2.0-E6753A?style=flat-square">
  <img alt="iOS" src="https://img.shields.io/badge/UI%2FAPI-iOS%2016%2B%20%7C%20system%20access%20build--specific-222222?style=flat-square">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-F05138?style=flat-square&logo=swift&logoColor=white">
  <img alt="Languages" src="https://img.shields.io/badge/languages-English%20%7C%20Tiếng%20Việt%20%7C%20简体中文-E6753A?style=flat-square">
</p>

<p align="center">
  <a href="docs/PATCH_GUIDE.md">Patch guide</a> ·
  <a href="#compatibility">Compatibility</a> ·
  <a href="#license">License</a>
</p>

> [!WARNING]
> Duy Mạnh Store is research software for personal device management. Keep a backup and use it only on devices and data you own. Simulator screenshots demonstrate UI only; they do not verify device-level access.

## Preview

<p align="center">
  <img src="docs/images/home.png" width="245" alt="Duy Mạnh Store Home">
  &nbsp;
  <img src="docs/images/patches.png" width="245" alt="Duy Mạnh Store Patches">
  &nbsp;
  <img src="docs/images/cleaner.png" width="245" alt="Duy Mạnh Store Cleaner">
</p>

## What's new in 1.1.0

- **Capability-based compatibility** — iOS 16+ can use the UI, secure server API and `.3105` parser. Device-level access is enabled only when the compiled backend supports the exact candidate and its local probe succeeds.
- **Wrong-password feedback** — importing a `.3105` patch with an incorrect password now shows "Incorrect password" instead of failing silently.
- **Onboarding for reinstalls** — onboarding reappears after overwriting the app with the same version, so fresh and overwritten installs both see the guided setup.

See the complete [Patch workspace guide](docs/PATCH_GUIDE.md).

## What's new in 1.0.1

- **Patch workspace v2** — build patches as a normal bundle-based directory tree under `On My iPhone/3105/Patches`; Apply and Export synchronize the workspace automatically.
- **Safer recovery** — original files are journaled before writes; Restore puts existing files back, removes files introduced by the patch, and removes patch-created directories once empty.
- **More capable Files tab** — independent tabs, preserved folder position, multi-selection, ZIP creation and extraction, plus a denser and more consistent grouped layout.
- **Responsive navigation** — iPad split-view and landscape support, optional Cleaner/Wallpaper tabs, stable search fields, and refined icon/row sizing.
- **Wallpaper guidance** — corrected PosterBoard activation steps, including the iOS 27 Collections prerequisite.

See the complete [Patch workspace guide](docs/PATCH_GUIDE.md).

## Highlights

- **App Data Browser** — resolves volatile container UUIDs to stable app bundle identifiers and exposes a native file workspace.
- **File operations** — search, preview, share, import multiple files, copy, move, paste, rename, delete, create files and folders, make ZIP archives, and safely handle name conflicts.
- **Portable `.3105` patches** — bundle-based rules survive container-ID changes between devices; projects may include files or folders, support optional password protection, and can be imported from Files or a secure website link.
- **API interception guard** — checks effective HTTP/HTTPS/SOCKS/PAC proxy settings and active packet-tunnel interfaces before authentication or patch download; detection blocks the app behind a five-second warning and then closes it.
- **Limited Cleaner** — scans only each app's `Library/Caches` and `tmp`, sorts recoverable size in either direction, supports bulk selection, and requires confirmation before deletion.
- **Wallpaper Lab** — imports `.tendies` packages, validates payloads, journals installed items, and resets only content installed by 3105.
- **No jailbreak installation** — 3105 does not install a persistent jailbreak, bootstrap, or daemon and does not inject code into third-party apps. Because it still uses device exploits and can modify app data, no universal guarantee can be made against every app's integrity or jailbreak-detection policy.
- **Localized interface** — English, Vietnamese, and Simplified Chinese.

## Compatibility

Build/UI/package compatibility and device-level capability are intentionally
separate. The current compiled offsets gate is iOS 17.0 through 26.0.x; it has
no iOS 16 or iOS 27 backend. A version inside that gate is still only a
candidate until its local capability probe succeeds.

| System | UI/API/parser | Compiled system-access status |
| --- | --- | --- |
| iOS 16.7.5 | Supported | unavailable; no offsets/provider |
| iOS 17.0–17.7.x | Supported | candidate; local probe required |
| iOS 18.0–18.7.1 | Supported | candidate; local probe required |
| iOS 26.0.x | Supported | candidate; local probe required |
| iOS 26.1+ / iOS 27 | Supported | unavailable in the compiled offsets backend |

Unknown builds fail closed for privileged features. The kernel/system-access
operation is never run merely because the app opened. See
[`docs/IOS_16_7_5_COMPATIBILITY.md`](docs/IOS_16_7_5_COMPATIBILITY.md) for the
repository audit and test matrix.

## Installation notes

- Device functionality requires signing with an **enterprise certificate**.
- SideStore, AltStore, 3uTools, and LiveContainer are not supported installation paths.
- The target bundle identifier is intentionally `com.apple.mobile.MobileHouseArrest`; changing it can break the MHA-C2 app-container workflow.
- The source tree does not contain certificates, provisioning profiles, signed applications, or IPA files; release assets may provide an unsigned IPA.

## Project layout

```text
Duy-Manh-Store/
├── ThreeOneOSFive/          # SwiftUI app, helpers, native bridges, localizations
├── ThreeOneOSFive.xcodeproj # Xcode project and 3105 scheme
├── patch-cloud-web/         # Patch Cloud website and VPS/Cloudflare Tunnel bundle
└── docs/images/             # Repository artwork and current UI previews
```

## Security and responsible use

Do not publish logs, app containers, cookies, account databases, or patch payloads containing personal data. Report security-sensitive issues privately to the maintainer.

## Credits

Duy Mạnh Store is based on the 3105 project developed and designed by [YangJiii](https://x.com/duongduong0908).

Special thanks to [0xjohnny](https://x.com/0xjohnny) for [FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop) and related research:

- [MobileHouseArrest-PoC](https://github.com/0xjohnnydev/MobileHouseArrest-PoC) — ContainerManager identity-trust bug
- [Geod-MCM-PoC](https://github.com/0xjohnnydev/Geod-MCM-PoC) — `geod` MobileContainerManager `partDomain` traversal
- [InstallCoordination-PoC](https://github.com/0xjohnnydev/InstallCoordination-PoC) — persisted-state and final-symlink chain
- [CFPrefsZeroFile-PoC](https://github.com/0xjohnnydev/CFPrefsZeroFile-PoC) — `cfprefsd` zero-file creation

The project also builds on work from Pocket Poster/Nugget, CrazyMind90, forcequitOS, Dopamine, and their contributors. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for full attribution and upstream links.

## License

Original portions of 3105 are distributed under the [GNU General Public License v3.0](LICENSE). Third-party components remain subject to their respective upstream copyright and license terms; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).


## Dynamic .3105 BPLIST
The patch codec accepts the legacy `3105PATCH\0bplist` envelope and the current plain BPLIST/XML envelope. Schema versions 1–9 are supported, including `packageID`, `isPasswordProtected`, `publicContentKey`, `keyFingerprint`, `encryptedPayload`, and `keyAADVersion`.

Runtime patching performs a persistent backup immediately before overwrite. Restore verifies the active replacement digest and restores the exact original bytes; after successful restore, transaction backup/staging artifacts are removed. The `.3105` library package is retained so the same patch can be enabled again and receives a fresh backup.
