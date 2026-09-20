## What's new in this version

First public release.

### New

- **Track any spell or item.** Blizzard's manager only shows its curated
  list; here everything can go on a bar of your own - via the button next to
  the search box, with `/fcd spell <ID>`, or by dropping it in from your
  bags, including spells the spellbook does not list. A dedicated section
  shows what their list leaves out.
- **Ranks stacked.** The same ability in thirty ranks becomes one entry
  showing the highest rank you know. The rank number sits on the icon.
- **One interface for everything.** Forever Cooldowns takes the place of
  Blizzard's cooldown window and, in Edit Mode, also replaces the settings
  dialogs of their bars. The values stay theirs: their "Save changes" saves
  ours along with it, and it survives a reload. Both can be switched off.
- **The same entries as Blizzard's manager.** The catalogue is read from
  their own display layer, so both windows show the same cooldowns in the
  same sections - including the ones you have not learned yet and the ones
  set to hidden.
- **Ready alerts.** What becomes ready lights up and stays marked for as
  long as it is ready - using Blizzard's own glow where the client has it.
  Optionally with a sound, configurable per bar and, differently, per entry.
- **Edit Blizzard's categories.** Multi-select, drag between sections,
  target buttons. Changes are written into their own layout.
- **Your own bars** with orientation, size, spacing, opacity, visibility and
  "Use on click" - configurable in a window styled after their Edit Mode,
  which the bars follow.
- **Profiles** to save, switch and share as text; optionally automatic on
  stance, form or specialisation.
- **English and German interface**, following your client's language;
  `/fcd lang de|en|auto` overrides it.

### Good to know

`/fcd check` shows what this client offers. Every API needed is probed
individually - if one is missing, only the feature built on it falls away,
not the addon.

This client does not hand the addon's saved variables back on login, so
Forever Cooldowns keeps a per-character second copy and restores from it.
`/fcd mirror` tells you where your settings came from.

If the client lists no cooldowns for a character at all, the first two tabs
stay empty - Blizzard's own window does too. Your own spells and items can
still be tracked on the other two tabs.
