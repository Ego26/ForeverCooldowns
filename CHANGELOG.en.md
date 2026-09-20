*English · [Deutsch](CHANGELOG.md)*

# Changelog

All notable changes to Forever Cooldowns.

## [0.2.0-beta]

### Added

- **Mirrored bars.** A bar of your own can show one of Blizzard's categories;
  its contents come from the same assignment the panel edits. We draw it, so a
  move shows up there immediately - no reload and not a single call on
  Blizzard's objects, which means no taint and no Lua errors. The *mirror*
  button sits on every section heading, and there is `/fcd mirror`.
- *Detach mirror* in the bar window: freezes the current contents, after which
  it is an ordinary bar.
- `/fcd mirror hide` explains how to hide Blizzard's own bars - in their
  window, because touching them from our side would create exactly the taint
  this route avoids.

### Changed

- The reload button and the status line in the panel now distinguish between a
  change that is still pending and one where only Blizzard's own bars have yet
  to catch up.
- Category names live in one place only (`Mirror.lua`), so the panel and the
  bars can no longer name them differently.

### Fixed

- **Lua errors on protected cooldown values.** Whether this client protects a
  value was probed once at login against an arbitrary spell. That is the wrong
  question: it is the individual value that is protected, not the client - a
  cooldown of zero arrives as an ordinary number, a running one protected. If
  the probe spell happened to be ready, the addon assumed every value was
  readable and threw an error on the first comparison. It now asks per value;
  this covers cooldowns, auras, charges and "usable".
- **Protected cooldown values no longer break an icon.** This client refuses
  even to have them passed on to the Blizzard cooldown widget ("Secret values
  are only allowed during untainted execution"). The attempt is now made once
  and not repeated after the first refusal; the icon then stands without
  swipe and without remaining time. `/fcd check` says which of the two cases
  applies.
- The probe for protected values runs against several spells instead of one.
  A single spell that happened to be ready made it fail reliably.
- A bar mirroring Blizzard's "Items" category is no longer mistaken for your
  own item bar and renamed.

## [0.1.0-beta]

### Added

- Panel for editing Blizzard's cooldown categories, narrow next to their
  window or wide with a tool column.
- Rank stacking showing the highest rank you know, plus downranking to a
  fixed rank.
- Separate tabs for any spell and for usable items. Add them with the button
  next to the search box, via `/fcd spell <ID>`, or by dropping them in from
  your bags - including spells the spellbook does not list.
- Takeover of Blizzard's cooldown window (`/fcd replace on|off`): FCD takes
  its place without theirs flashing up first.
- Takeover of their Edit Mode settings dialogs (`/fcd editui on|off`).
  Reading and writing goes through their own path, and their "Save changes"
  saves ours along with it.
- Ready alerts: a flash on the transition, then a lasting mark for as long as
  it is ready, optionally with a sound. Uses Blizzard's spell alert glow where
  the client has it. Configurable per bar and, differently, per entry.
- Your own bars with an options window styled after Edit Mode: orientation,
  columns, size, spacing, opacity, visibility including "Never", tooltips and
  "Use on click".
- Layout profiles with text import and export, and optional profile switching
  on stance, form or specialisation.
- Two ways to write Blizzard's categories: instantly through their data model,
  or safely through SetLayoutData. A backup is taken before every write, and
  `/fcd restore` undoes the last one.
- A second storage path inside Blizzard's layout (`Store.lua`), because this
  client creates no SavedVariables for the addon. `/fcd store` writes
  immediately and reads back to verify.
- Rounded icon corners via a mask (`/fcd round on|off`).
- Diagnostic commands: `/fcd check`, `/fcd probe`, `/fcd log`, `/fcd layout`,
  `/fcd shown`, `/fcd editmode`, `/fcd editsettings`.

### Known limitations

- Blizzard's layout can only be switched in their own window (`/fcd blizz`);
  their layout manager is protected.
- Instant mode marks Blizzard's viewer as tainted; their aura access then
  fails until the next reload.
- In this client the addon's SavedVariables are not returned. The data
  therefore rides in Blizzard's layout; if the client rewrites that layout
  itself, it can be lost. This is checked regularly and written back.
- If a client protects cooldown values, the end of a cooldown cannot be
  detected and ready alerts are unavailable. `/fcd check` says whether that
  applies here.
