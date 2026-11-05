# Third-party skills

These skills were copied into this repo (not installed via a shell installer) after a manual
review. Only the skill folders were copied; no hooks, plugins, MCP servers, or proxies were added.

| Folder | Upstream | License | Notes |
|---|---|---|---|
| `flutter-architecture`, `state-management-riverpod`, `widget-composition`, `ui-states-and-feedback`, `error-handling-typed-results`, `navigation-and-routing`, `testing-strategy`, `accessibility-as-code`, `design-system-structure`, `flutter-conventions-index`, `scaffold-feature-module` | https://github.com/zakariaf/Flutter-Skills | MIT | Curated subset (11 of 40). Scripts in these folders are local-only shell helpers and are not required for the guidance to apply. |
| `ui-ux-pro-max` | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill | MIT | `SKILL.md` path references were rewritten from `${CLAUDE_PLUGIN_ROOT}/.claude/skills/...` to `.opencode/skills/...` so the local Python search script resolves from the repo root. `stack/.mcp.json` was not copied. |

Search script requires Python 3. On Windows use `py -3`:

```powershell
py -3 .opencode/skills/ui-ux-pro-max/scripts/search.py "portfolio" --stack flutter -n 2
```
