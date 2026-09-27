# ComfyMacro Changelog

## 0.3 Beta – 27.09.2026
- Added reliable ComfyHub minimap bundling support.
- The standalone minimap button now hides while ComfyHub bundling is active.
- Disabling bundling restores the button according to ComfyMacro's own minimap visibility setting.
- Re-enabling bundling hides the standalone button again immediately.


## 0.2 Beta – 27.09.2026
- Builder now automatically inserts `#showtooltip` for the first spell/profession block when needed.
- Automatic question-mark macro icons therefore adopt the selected spell/profession icon without requiring an extra builder step.
- Custom icon selection remains available and does not remove the generated tooltip line.


## 0.1 Beta – 27.09.2026

- Initial ComfyMacro release.
- Added a visual macro Builder with target, cast, mouseover, focus, self-cast, trinket, profession, emote, say and yell blocks.
- Added a guided Assistant that only shows relevant next choices and keeps a fixed explanation panel visible.
- Added automatic spell icons through WoW's question-mark macro icon and `#showtooltip`.
- Added a custom macro icon picker.
- Added templates for fixed-tank heals, mouseover heals, burst macros, profession shortcuts, emotes and chat.
- Added learned-spell and profession discovery with modern/legacy API fallbacks.
- Added a My Macros page for viewing and editing existing macros.
- Added a standalone minimap button and slash commands.
- Added the shared Comfy Suite Info tab and family metadata.
- Macro creation remains subject to WoW secure-action, cooldown and combat restrictions.
