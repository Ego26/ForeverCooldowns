# Forever Cooldowns

**Blizzard's Cooldown Manager only shows what is on its list. Forever
Cooldowns removes that limit.**

Any spell from your spellbook, any usable item — on a bar of your own, handled
the same way as their categories. Plus editing those categories in a window
that is actually workable.

Type `/fcd`.

---

## The problem it was built for

**World of Warcraft: Forever** has Blizzard's Cooldown Manager and, at the same
time, Classic-style spell ranks. Together they make its list unusable: thirty
rows that all look identical, because they are the same ability in thirty
ranks.

Forever Cooldowns stacks them into **one** entry showing the highest rank you
know. Thirty rows become one.

---

## What it does

### Any spell, any item

Two tabs of your own, handled like Blizzard's categories. One section is
called **"Not in Blizzard's manager"** and shows exactly what their curated
list leaves out. Items can be dragged straight from your bags onto the panel.

### Edit Blizzard's categories

Select several entries (Ctrl, Shift) and move them between *Essential*,
*Utility* and *Hidden* — by dragging or with the target buttons. Changes go
into their own layout, not into a parallel world of ours.

### Ranks

Rank number on the icon. Either always the highest rank you know, or a fixed
one (downranking). Learn a new rank and nothing needs adjusting.

### Your own bars

Orientation, columns, icon size, spacing, opacity, visibility — per bar, in a
window styled after Blizzard's Edit Mode. The bars follow it, too: open Edit
Mode and they become movable and labelled.

### Profiles

Save layouts, switch between them, share them as text. Optional automatic
switching on stance, form or specialisation.

---

## Commands

| Command | Effect |
| --- | --- |
| `/fcd` | open the panel |
| `/fcd wide` | narrow or wide view |
| `/fcd blizz` | fetch Blizzard's window (layout switching lives there) |
| `/fcd log` | all output, copyable |
| `/fcd check` | what this client's API actually offers |
| `/fcd help` | full list |

---

## Honestly

**Instant mode has a price.** Changes apply without reloading because they go
through Blizzard's own data model. Once addon code touches that, it counts as
*tainted* for the rest of the session and their viewer can no longer read
auras — until the next `/reload`. It affects their display, not ours. If you
would rather not: `/fcd instant off` writes safely, but only takes effect on
reload.

**Switching layouts only works in their window.** Their layout manager is
protected; calling it from outside would taint the session. `/fcd blizz`
fetches their window for that.

**Before every write** the addon checks that the layout blob survives our
encoding chain intact, and takes a backup. `/fcd restore` undoes the last one.
