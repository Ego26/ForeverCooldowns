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
  would be shown twice once FCD displays their categories. It flips the same
  switch you would find in the game options (a CVar); if the client has none,
  their loadable addon is disabled instead and it takes effect on the next
  reload. Their frames are not touched - that would be exactly the taint this
  route avoids. FCD asks once on your first login; answering is one click and
  reversible at any time.
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
