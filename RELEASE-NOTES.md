## What's new in 0.2.0-beta

### Instant, and without a single error

Moving a cooldown between Blizzard's categories used to leave a choice, and
neither half of it was good: write through their Lua and see it at once, but
taint their viewer so it throws red errors on every target and aura event - or
write safely and wait for a reload.

The C function that would do both, `SetCooldownViewerCategorySet`, does not
exist in this client. So this version takes a third route: **we draw the
category ourselves.**

- **Mirrored bars.** The *mirror* button on any section heading in the panel
  creates a bar of your own showing exactly that category. Because the bar is
  ours, a move shows up there in the same second - no reload, no call on
  Blizzard's objects, and therefore no error. `/fcd mirror` does the same
  from chat.
- Everything else about the bar stays yours to set: orientation, size,
  visibility, ready alerts, and ready alerts per single entry.
- **Detach mirror** in the bar window freezes the current contents, after
  which it is an ordinary bar you can edit by hand.
- `/fcd mirror hide` explains how to hide Blizzard's own bars, which still
  catch up only on reload. You do that in their window - if the addon did it,
  that would be exactly the taint this route avoids.

### Changed

- The reload button and the status line now distinguish between a change that
  is still pending and one where only Blizzard's own bars have yet to catch
  up.
- Category names live in one place, so the panel and the bars cannot name them
  differently.

### Fixed

- A bar mirroring Blizzard's "Items" category is no longer mistaken for your
  own item bar and renamed.
