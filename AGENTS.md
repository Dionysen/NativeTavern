# NativeTavern Agent Instructions

## Cross-platform UI/UX

Ship one shared product UI. Android, iOS, and desktop must match in layout,
spacing, density, AppBar actions, FABs, and list chrome unless a platform API
forces a difference (pickers, permissions, Live2D host, share sheets).

- Fix chrome in theme / shared widgets (`ChromeControls`, settings tiles,
  `spacedAppBarActions`), not with `Platform.isX` UI branches.
- Prefer circular icon-only FABs with `tooltip` over extended labeled FABs for
  primary create actions (e.g. home new chat).
- See `.cursor/rules/cross-platform-ui.mdc` for the full rule.

## Release work

Before any packaging, store upload, release announcement, or version bump:

1. Read `docs/release-runbook.md` completely.
2. Inspect the existing `.sh` scripts and list relevant `.env` key names without
   printing secret values.
3. Check `git status`, the current `pubspec.yaml` version, recent tags, and the
   latest Discord release announcement.

Release packages must be produced by the repository scripts:

- iOS: `./build_ios.sh`
- Android APK and AAB: `./build_android.sh`
- macOS: `./build_macos.sh`

Do not replace these scripts with direct `flutter build`, Gradle, or
`xcodebuild` packaging commands. A direct command is allowed only while fixing
the corresponding build script, and the final artifact must still be rebuilt
with that script.

Use `tool/discord_release.sh` for Discord release history and announcements.
Do not use a browser when the configured Discord bot API is available.

Treat `.env` values as secrets. Never print tokens, service-account JSON,
access keys, private keys, or complete authorization headers.

Unless the user explicitly overrides these defaults:

- Apple uploads go to internal TestFlight only; do not submit App Store review.
- Google Play receives the AAB; direct APK distribution goes to Cloudflare R2.
- License review is outside engineering release scope and must not block an
  otherwise valid build.
- Work directly on `main` for the current regression/release phase.

Do not report a release complete until the external platform states, artifact
checksums, Git commit, remote branch, and release tag have all been verified.
