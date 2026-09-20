## What's new in 0.2.0-beta

### Instant, and without a single error

Moving a cooldown between Blizzard's categories used to leave a choice, and
neither half of it was good: write through their Lua and see it at once, but
taint their viewer so it throws red errors on every target and aura event - or
write safely and wait for a reload.

The C function that would do both, `SetCooldownViewerCategorySet`, does not
exist in this client. So this version takes a third route: **we draw the
category ourselves.**

- **Mirrored bars, on from the start.** Your bars show exactly what sits in
  Blizzard's categories. Because the bars are ours, a move shows up there in
  the same second - no reload, no call on Blizzard's objects, and therefore no
  error. Nothing to switch on; the *mirror* button on a section heading adds
  further categories, and `/fcd mirror` does the same from chat.
- Everything else about the bar stays yours to set: orientation, size,
  visibility, ready alerts, and ready alerts per single entry.
- **Detach mirror** in the bar window freezes the current contents, after
  which it is an ordinary bar you can edit by hand.
- `/fcd mirror hide` explains how to hide Blizzard's own bars, which still
  catch up only on reload. You do that in their window - if the addon did it,
  that would be exactly the taint this route avoids.

### Changed

- **`/fcd solo` switches Blizzard's own bars off.** Otherwise everything
  would be shown twice once FCD displays their categories. It disables their
  loadable addon - which brings the frames, not the data - and takes effect
  on the next reload. Their frames are not touched, because that would be
  exactly the taint this route avoids. If a client does not have that addon,
  `/fcd solo` says so and names the steps in Blizzard's own window.
- **The default bars mirror Blizzard's categories.** There used to be two
  empty bars there, and a change became visible only once somebody found the
  "mirror" button. Nobody can know that in advance, so it is now the starting
  state: install and done. Existing profiles catch up once - but only where
  the default bar was left untouched and empty.
- The reload button and the status line now distinguish between a change that
  is still pending and one where only Blizzard's own bars have yet to catch
  up.
- Category names live in one place, so the panel and the bars cannot name them
  differently.

### Fixed

- **An empty panel repairs itself.** If no data arrives at login and
  Blizzard's cooldown feature is switched off, FCD switches it back on and
  says so. The reason: the CVar `cooldownViewerEnabled` does not switch off
  the display but the whole feature - including
  `GetCooldownViewerCacheInfo`, which is where the panel and the bars get
  their data. Within the same session this goes unnoticed; it only shows
  after a reload. FCD no longer touches that CVar.
- **Mirrored bars showed too much.** The catalogue knows a category for
  every cooldown, including abilities Blizzard's bars never display - "Heroic
  Strike" sits under "Utility" and still appears nowhere in theirs. What is
  shown now is what Blizzard would show: whatever is in their category list,
  plus whatever you assigned yourself.
- **Bars could not be clicked in Blizzard's Edit Mode.** Their interface puts
  a surface over the screen that swallows clicks. Bars now move up one strata
  for as long as Edit Mode is open - the same treatment the panel already had.
- **Lua errors on protected cooldown values.** Whether this client protects a
  value was probed once at login against an arbitrary spell - but it is the
  individual value that is protected, not the client. If that spell happened
  to be ready, the addon assumed every value was readable and threw an error
  on the first running cooldown. It now asks per value.
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
