# ComfyMacro

**Version 0.2 – Beta**  
**Tested target: WoW Forever 1.60.1 / Build 70009 / Interface 16001**  
Author: **TheRealDoubleG**  
Discord: **the.real.double.g**

ComfyMacro is a guided in-game macro builder for the Comfy Suite on WoW Forever. It is designed for players who want useful macros without having to memorize WoW macro syntax.

## 0.2 Beta

- **Builder** – combine simple blocks such as target, cast, trinkets, professions, emotes and chat commands.
- **Assistant** – guided step-by-step creation with only the relevant next choices shown.
- **Templates** – common starting points for healer, burst, profession, emote and chat macros.
- **My Macros** – browse existing character/account macros and inspect their body.
- **Automatic spell icon** – spell macros use WoW's question-mark macro icon plus `#showtooltip`, so WoW displays the spell icon automatically.
- **Custom icon picker** – switch from automatic mode to a manually selected macro icon.
- **Fixed explanation area** – every builder block and assistant step explains what it does.
- Detects learned spells and professions when the WoW Forever client exposes the required APIs.
- German UI on a German client, English otherwise.
- Shared Comfy Suite Info-tab and menu style.

## Example macros

Fixed tank heal:

```
#showtooltip Flash Heal
/targetexact MainTank
/cast Flash Heal
```

Mouseover heal:

```
#showtooltip Flash Heal
/cast [@mouseover,help,nodead][] Flash Heal
```

Burst helper:

```
#showtooltip Berserking
/use 13
/use 14
/cast Berserking
```

Profession shortcut:

```
#showtooltip Alchemy
/cast Alchemy
```

## WoW restrictions

ComfyMacro creates normal World of Warcraft macros only. It does not automate gameplay and cannot bypass the secure-action, global-cooldown or one-hardware-input rules. If two selected actions cannot legally happen from one key press, ComfyMacro explains the limitation instead of pretending otherwise.

## Slash commands

- `/comfymacro`
- `/cm`

## Comfy Suite

ComfyMacro follows the shared Comfy Suite UI standard and remains fully usable without ComfyHub.


## Automatic spell icons

From 0.2 onward, the Builder automatically adds `#showtooltip <spell>` when a spell or profession block is present and no explicit showtooltip block was added. This makes WoW's automatic question-mark macro icon display the selected spell/profession icon by default. A custom icon can still be selected at any time.
