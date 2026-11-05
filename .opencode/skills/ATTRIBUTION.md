# Third-party skills

These skills were copied into this repo (not installed via a shell installer) after a manual review.
Only skill folders were copied; no hooks, plugins, MCP servers, or proxies were added.

| Folder | Upstream | License | Notes |
|---|---|---|---|
| `flutter-clean-arch`, `flutter-state`, `flutter-testing`, `flutter-forms`, `flutter-dart-style`, `flutter-concurrency`, `flutter-run` | https://github.com/gabuldev/flutter-skills | MIT | Markdown only, no scripts. Matches this project's Cubit + Clean Architecture stack. Their `flutter-di` skill was skipped because it assumes `flutter_injections` (this project uses `get_it`). `flutter-theming`, `flutter-design-system`, `flutter-monorepo`, `flutter-web`, `flutter-store-cd`, `flutter-caching`, `flutter-new-module`, `flutter-accessibility` were skipped as monorepo/web/deployment-specific or redundant. |
| `widget-composition`, `accessibility-as-code`, `design-system-structure` | https://github.com/zakariaf/Flutter-Skills | MIT | Kept because they are stack-agnostic: widget/layout craft, semantics, theme tokens. The Riverpod-specific skills from that repo were removed after the project chose bloc. |
| `ui-ux-pro-max` | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill | MIT | `SKILL.md` path references were rewritten from `${CLAUDE_PLUGIN_ROOT}/.claude/skills/...` to `.opencode/skills/...` so the local Python search script resolves from the repo root. `stack/.mcp.json` was not copied. |

The Python search script requires Python 3. On Windows use `py -3`:

```powershell
py -3 .opencode/skills/ui-ux-pro-max/scripts/search.py "portfolio" --stack flutter -n 2
```