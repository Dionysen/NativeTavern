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
