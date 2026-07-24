# Mac App Store viability audit (2026-07-23)

Prep done while Apple Developer Program approval is pending. Two distribution
paths, in recommended order:

## Path 1 — Notarized direct distribution (ready today)

Everything is already in place; no code changes needed. Once the account is
approved:

1. Create a "Developer ID Application" certificate (Xcode → Settings →
   Accounts, or developer.apple.com → Certificates).
2. Store notary credentials once:
   `xcrun notarytool store-credentials sweepwise-notary --apple-id … --team-id … --password <app-specific>`
3. Ship: `SWEEPWISE_SIGN_IDENTITY="Developer ID Application: … (TEAMID)" ./scripts/notarize.sh`

`bundle.sh` already signs with hardened runtime when `SWEEPWISE_SIGN_IDENTITY`
is set; `notarize.sh` submits, staples, verifies with Gatekeeper, and re-zips.
See docs/NOTARIZING.md.

Hardened-runtime note: the LLM feature spawns external CLIs (claude/codex/
gemini). Hardened runtime permits spawning other signed binaries, so this
works unchanged under notarization.

## Path 2 — Mac App Store (needs rework first)

App Sandbox is mandatory on MAS. Audit of what breaks:

| Area | Sandbox impact |
|---|---|
| `NSHomeDirectory()` (SettingsStore.defaultRoots, LLMProvider.defaultSearchPaths) | Returns the app *container* home, not the real home. Every default root would silently point at an empty container dir. Must resolve the real home via `getpwuid(getuid())` and gate access on user grants. |
| Scan roots (`~/Library/Caches`, `~/Library/Application Support`, `~/Library/Developer`, `~/Documents/Dev`, `~/Downloads`) | No access by default. Fix is the DaisyDisk pattern: one NSOpenPanel "grant access to your home folder" on first run, persisted as a security-scoped bookmark, wrapped in `startAccessingSecurityScopedResource()` around scans/deletes. |
| Dot-folder rules (`~/.cache`, `~/.npm`, `~/.cargo`, `~/.gradle`, `~/.ollama`, `~/.lmstudio`) | Covered by a whole-home grant; individually unpickable in practice (hidden in the panel). Whole-home grant is effectively required. |
| Deletion (`FileManager.trashItem` / `removeItem`) | Works on granted paths inside a scoped-access block. No change beyond the bookmark plumbing. |
| **LLM feature (LLMExplainer)** | **Blocker as designed.** Spawns user-installed CLIs from `/opt/homebrew/bin` etc.; children inherit the sandbox, so the CLIs can't reach the network or read their own config (`~/.claude`, keychain). Also a likely App Review objection. MAS build must either drop the feature or replace it with direct API calls over URLSession (then add the `network.client` entitlement). |
| CLI detection (`detectInstalled`) | Probes outside the container fail; feature degrades to "not installed". Harmless but confirms the feature is dead under sandbox. |

**Verdict:** core scan/clean is MAS-viable with (a) real-home resolution,
(b) grant-home-folder onboarding + security-scoped bookmarks, and (c) the LLM
feature cut or rebuilt on direct API. Estimate: a real feature-rework branch,
not packaging work. Do Path 1 first.

MAS packaging, when the rework lands: sign with "Apple Distribution" +
entitlements (`Assets/Sweepwise-mas.entitlements`) + embedded provisioning
profile, build a pkg with `productbuild --sign "3rd Party Mac Developer
Installer: …"`, upload via Transporter, submit in App Store Connect.
