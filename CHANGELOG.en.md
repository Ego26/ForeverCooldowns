*English · [Deutsch](CHANGELOG.md)*

# Changelog

All notable changes to Forever Cooldowns.

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
- A per-character second copy: this client does not hand back the
  account-wide file on login although it sits valid on disk. A full copy is
  therefore written on logout and restored from on the next login.
  `/fcd mirror` shows it.
- The catalogue comes from Blizzard's own display layer, so both windows
  show the same entries in the same sections, including the unlearned and
  the hidden ones.
- Diagnostic commands: `/fcd check`, `/fcd probe`, `/fcd log`, `/fcd layout`,
  `/fcd shown`, `/fcd editmode`, `/fcd editsettings`, `/fcd tab`,
  `/fcd provider`, `/fcd scan`, `/fcd catalog`.

### Known limitations

- Blizzard's layout can only be switched in their own window (`/fcd blizz`);
  their layout manager is protected.
- Instant mode marks Blizzard's viewer as tainted; their aura access then
  fails until the next reload.
- In this client the account-wide file arrives empty on login although it
  sits valid on disk. The data is therefore carried by the per-character
  second copy, with Blizzard's layout as a third net. `/fcd mirror` says
  where it came from.
- If the client lists no cooldowns for a character, the first two tabs stay
  empty - so does Blizzard's own window. Your own spells and items can be
  tracked independently of that.
- If a client protects cooldown values, the end of a cooldown cannot be
  detected and ready alerts are unavailable. `/fcd check` says whether that
  applies here.
