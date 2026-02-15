# WA_Addons

Standalone World of Warcraft addons converted from WeakAuras.

## Why?

Blizzard has been increasingly restricting WeakAuras and similar runtime scripting addons. Some servers and tournaments have outright blocked them. This repo converts useful WeakAuras into proper standalone addons that work without WeakAura installed.

## Repo Structure

Each addon lives in its own top-level folder:

```
WA_Addons/
├── AddonName/
│   ├── AddonName.toc          # WoW addon manifest
│   ├── AddonName.lua          # Main addon code
│   └── Libs/                  # Bundled libraries (LibStub, LibDataBroker, etc.)
├── .github/workflows/
│   └── release.yml            # Auto-releases to GitHub + CurseForge on push to main
└── README.md
```

## How to Add a New Addon

1. **Create a folder** matching the addon name (e.g. `MyAddon/`)
2. **Create `MyAddon.toc`** with standard WoW TOC format:
   ```
   ## Interface: 120001
   ## Title: MyAddon
   ## Notes: What it does.
   ## Author: SindreMA
   ## Version: 1.0.0
   ## SavedVariables: MyAddonDB

   Libs/LibStub/LibStub.lua
   MyAddon.lua
   ```
3. **Create `MyAddon.lua`** — convert the WeakAura logic:
   - WeakAura `init` action → `ADDON_LOADED` event handler
   - WeakAura triggers → register the same WoW events on a frame
   - WeakAura `_G.` globals → `SavedVariables` for persistence
   - WeakAura LibStub calls → bundle the libs in `Libs/`
4. **Bundle any required libraries** in `Libs/` (LibStub, LibDataBroker-1.1, LibDBIcon-1.0, CallbackHandler-1.0, etc.)
5. **Update the workflow** in `.github/workflows/release.yml`:
   - Add a new env var: `MYADDON_CF_ID: "curseforge-project-id"`
   - Add a case in the "Read version from TOC" step
   - Add the CurseForge upload step for the new addon
6. **Bump the `## Version:` in the TOC** to trigger a new release on push

## Common WeakAura → Addon Conversion Patterns

| WeakAura Concept | Addon Equivalent |
|---|---|
| Custom trigger on event `X` | `frame:RegisterEvent("X")` in `OnEvent` handler |
| Init action (`actions.init.custom`) | `ADDON_LOADED` event handler |
| `_G.MyVar` for state | `SavedVariables` in TOC + init defaults on load |
| LibStub calls (LibDataBroker, LibDBIcon) | Bundle libs in `Libs/`, list in TOC before main lua |
| `aura_env` | Local variables in addon scope (`local addonName, ns = ...`) |
| Trigger `custom_type = "event"` | `frame:SetScript("OnEvent", handler)` |
| Trigger `custom_type = "status"` | `OnUpdate` handler or periodic timer |
| WeakAura display (text/icon/bar) | Usually not needed — most converted addons are logic-only |

## Release Pipeline

The GitHub Actions workflow (`.github/workflows/release.yml`) automatically:
1. Triggers on push to `main` (when addon files change) or manual dispatch
2. Reads the version from the addon's `.toc` file
3. Skips if a GitHub release with that version already exists
4. Packages the addon folder as a zip
5. Creates a GitHub Release with the zip attached
6. Uploads to CurseForge via their API

**Required secrets:** `CF_API_KEY` — get one from https://wow.curseforge.com/account/api-tokens

## Current Addons

| Addon | Source WeakAura | CurseForge | Description |
|---|---|---|---|
| [AutoQueue](AutoQueue/) | [wago.io/3IxDUtinb](https://wago.io/3IxDUtinb) | [CurseForge](https://www.curseforge.com/wow/addons/autoqueue-wa) | Auto-accepts LFG role checks. Minimap button to toggle on/off. |
| [FrameScale](FrameScale/) | — | — | Set custom scaling for any UI frame. Minimap button to toggle scale mode, right-click for settings panel. |
| [DetailsQuickKeybinds](DetailsQuickKeybinds/) | [wago.io/wJjtCErAd](https://wago.io/wJjtCErAd) | — | Dynamic modifier-key keybinds for Details! windows. Hold or toggle to switch views, segments, attributes. Full settings UI. |
