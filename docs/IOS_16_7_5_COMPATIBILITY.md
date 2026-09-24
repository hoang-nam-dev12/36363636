# iOS 16.7.5 Compatibility and Secure Client Audit

Audit date: 2026-09-24. Upstream reference: `YangJiiii/3105` at commit
`a72617ed`. This document separates build/UI/package compatibility from
privileged device access. A green UI build is not evidence of kernel or
container capability.

## Phase 1 — repository audit

| File / symbol | Role | OS dependency / finding | Risk |
| --- | --- | --- | --- |
| `App.swift`, `AppState.detectSupport()` | launch and capability status | previously used one broad version allow-list and automatically ran the exploit | automatic privileged work could freeze/restart a device |
| `helpers/SupportPolicy.swift` | support policy | previously described iOS 26.0–26.6.1 and selected iOS 27 builds as supported even though the compiled offsets gate is narrower | UI could claim support not provided by the backend |
| `helpers/KernelExploit.swift` | Swift bridge to native access | calls `kexploit_opa334()` and `sandbox_escape()` | must never run for an unknown build |
| `kexploit/offsets.m`, `offsets_init()` | native offsets | hard-gates `17.0 <= system < 26.1`; there are no iOS 16 offsets | lowering the deployment target cannot create the missing primitive |
| `kexploit/kexploit_opa334.m` | kernel R/W chain | contains build- and SoC-sensitive behavior | copying offsets between major releases is unsafe |
| `helpers/ContainerStore.swift` | MCM activation, metadata scan and inode fallback | requires access granted by the system backend; MCM refusal alone is not solved by UI changes | direct container access is unavailable without a verified provider |
| `helpers/PatchPackageCodec.swift` | `.3105` inspect/encrypt/decrypt | schemas 1…9, CryptoKit AES-GCM and CommonCrypto PBKDF2; APIs are available on iOS 16 | parser is independently portable to iOS 16 |
| `helpers/PatchTransaction.swift` | apply/restore journal | validates paths, writes atomically, verifies hashes and rolls back | must stay disabled when container write capability is absent |
| `project.pbxproj` | build settings | deployment target is already iOS 16.0, Swift 5 | build compatibility was not the blocker |

## Phase 2 — current compatibility matrix

`Candidate` means the provider is compiled and must still pass a real probe on
the exact device/build. It does not mean universal support.

| iOS | UI | `.3105` parser | Repository/API | Container access | System access | Patch apply | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 16.7.5 | Yes | Yes (schemas 1…9) | Yes | No verified provider | No offsets/backend | Disabled | network/package-only |
| 17.0–17.7.x | Yes | Yes | Yes | candidate after probe | compiled candidate | only after verified capability | candidate |
| 18.0–18.7.1 | Yes | Yes | Yes | candidate after probe | compiled candidate | only after verified capability | candidate |
| 26.0.x | Yes | Yes | Yes | candidate after probe | compiled offsets candidate | only after verified capability | candidate |
| 26.1+ | Yes | Yes | Yes | no compiled verified provider | native offsets gate rejects it | disabled | network/package-only |
| iOS 27 builds | Yes | Yes | Yes | no compiled verified provider | native offsets gate rejects them | disabled | network/package-only |
| unknown/future | when deployment permits | parser-only | Yes | disabled | disabled | disabled | fail closed |

## Phase 3 — iOS 16.7.5 conclusion

1. The old Swift support policy blocked 16.7.5 before capability probing.
2. The deployment target already permits iOS 16.
3. The SwiftUI and networking code can compile for iOS 16.
4. The `.3105` codec does not depend on iOS 17-only APIs.
5. MCM/container access is not verified on iOS 16.7.5 in this repository.
6. The compiled system-access provider does not support iOS 16.7.5.
7. `offsets_init()` explicitly rejects versions below 17.0; no iOS 16 offset
   table exists.
8. No audited dependency forces the UI/API/parser to iOS 17.
9. UI, maintenance configuration, license verification, repository discovery,
   encrypted package download and package inspection can run on iOS 16 now.
10. Container read/write and patch apply need a separately verified iOS 16
    access mechanism. This change intentionally does not invent one.

## Phase 4 — implemented architecture

- `DeviceEnvironment` records OS version, build, model, architecture and app
  version/build.
- `DeviceCapability`, `DeviceCapabilities` and `CapabilityState` separate
  detection, candidate status and verified capabilities.
- `DeviceAccessProvider` is implemented only by the safe network provider.
  There is no fake `IOS16AccessProvider`.
- `CompatibilityManager` always enables repository networking and only exposes
  privileged capabilities after a real local probe.
- `AppLifecycleCoordinator` performs a debounced, single-flight foreground
  check and reuses a valid session.
- `DeviceIdentityProvider` creates a P-256 signing key in Secure Enclave when
  available, otherwise a this-device-only Keychain key. The private key never
  leaves the device.
- `AuthenticationService` stores an opaque session in Keychain and does not
  re-verify while it remains valid.
- `APIClient` signs `METHOD + PATH + TIMESTAMP + NONCE + SHA256(BODY)` and keeps
  normal TLS certificate validation enabled.
- `PatchDownloadManager` obtains one 60-second JWT per file, downloads up to ten
  files concurrently into memory, verifies size/SHA-256, then the existing UI
  imports packages serially to preserve `PatchProjectStore` transaction safety.

Opening the app never initializes kernel/system access. That operation remains
explicit and is unavailable when the compiled provider is not a verified
candidate.

## Server protocol

| Endpoint | Authentication | Purpose |
| --- | --- | --- |
| `GET /api/v1/config` | public | features, maintenance, compatibility policy |
| `POST /api/v1/client/open` | P-256 signed body | cold/foreground authentication alternative |
| `POST /api/v1/license/verify` | P-256 signed body | bind device, verify license, issue opaque session |
| `POST /api/v1/download/token` | session + P-256 signed body | issue independent one-time JWTs for 1–10 file IDs |
| `GET /api/v1/download/3105` | one-time JWT | claim and return one encrypted `.3105` package |

The server stores only the public device key, hashed session token, nonce hash
and hashed download token. A token state can only move
`issued → claimed → completed/failed`; it cannot return to `issued`.

## Regression checklist

- Cold launch and foreground resume use a single in-flight authentication.
- A short background transition reuses the Keychain session.
- Offline/timeout errors do not trigger privileged initialization.
- Invalid, expired, banned and device-limit licenses remain distinct errors.
- Replayed nonce and reused JWT are rejected.
- 1, 3 and 10 downloads use separate JWT/JTI values and verify SHA-256.
- iOS 16.7.5 keeps UI/API/parser enabled and privileged patch apply disabled.
- iOS 17/18/26.0 still require provider probing before patch application.
- iOS 26.1+, iOS 27 and unknown builds fail closed for system access.

Device-level validation still requires physical test devices. A Windows build
cannot replace Xcode compilation, code signing or hardware capability tests.
