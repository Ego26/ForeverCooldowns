![Forever Cooldowns](https://raw.githubusercontent.com/Ego26/ForeverCooldowns/main/branding/banner-1696-en.png)

# Forever Cooldowns

**Blizzard's Cooldown Manager only shows what is on its list. Forever
Cooldowns removes that limit.**

Any spell, any usable item — on a bar of your own, handled the same way as
their categories. And more than that: Forever Cooldowns takes the place of
their window, and in Edit Mode it also replaces the settings dialogs of their
own bars.

Type `/fcd`.

> **Built for World of Warcraft: Forever.** Every function it needs is probed
> individually, so it also runs where a client offers less — `/fcd check`
> lists what yours supports.
>
> **Available in English and German.** It follows your client's language;
> `/fcd lang de|en|auto` overrides that.

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
list leaves out. The `+` next to the search box takes any spell or item ID —
including things the spellbook does not list at all. Items can also be dragged
straight from your bags.

### Blizzard's categories, visible at once

Your bars show what sits in Blizzard's categories from the start — the same
assignment the panel edits, but drawn by us. A move therefore shows up there
in the same second: no reload, no call on Blizzard's objects, and so no error
message either.

Nothing to set up. The **mirror** button on a section heading adds further
categories or takes them out again, and `/fcd mirror` does the same from
chat.

### Ready alerts

When something becomes ready it lights up — using Blizzard's own spell alert
glow where the client has it — and stays marked for as long as it is ready.
Optionally with a sound, chosen from the sounds this client actually has.

Configurable per bar and, via **Set per entry**, differently for individual
icons. A silent bar with exactly one alerting spell is possible — and the
other way round, exactly one of twenty left out.

### One interface for everything

Forever Cooldowns takes over Blizzard's cooldown window and, in Edit Mode, the
settings dialogs of **their** bars as well: orientation, icon size, spacing,
opacity, visibility.

The values stay theirs. Reading and writing goes through their own path — their
interface updates by itself, their "Save changes" saves ours along with it, and
it survives a reload. If you would rather keep their windows:
`/fcd replace off` and `/fcd editui off`.

**The price:** changing one of their bars through our window taints their
viewer, exactly as instant mode does — it then throws errors on target and
aura events until the next `/reload`. The addon says so the first time.

### Edit Blizzard's categories

Select several entries (Ctrl, Shift) and move them between *Essential*,
*Utility* and *Hidden* — by dragging or with the target buttons. Changes go
into their own layout, not into a parallel world of ours.

### Ranks

Rank number on the icon. Either always the highest rank you know, or a fixed
one (downranking). Learn a new rank and nothing needs adjusting.

### Your own bars

Orientation, columns, icon size, spacing, opacity, visibility including
*Never*, tooltips and *use on click* — per bar, in a window styled after
Blizzard's Edit Mode. The bars follow it, too: open Edit Mode and they become
movable and labelled.

### Profiles

Save layouts, switch between them, share them as text. Optional automatic
switching on stance, form or specialisation.

---

## Commands

| Command | Effect |
| --- | --- |
| `/fcd` | open the panel |
| `/fcd wide` | narrow or wide view |
| `/fcd spell <ID>` | add any spell |
| `/fcd lang de\|en\|auto` | interface language |
| `/fcd replace on\|off` | whether FCD takes the place of their window |
| `/fcd editui on\|off` | our own window in Edit Mode |
| `/fcd blizz` | fetch Blizzard's window (layout switching lives there) |
| `/fcd log` | all output, copyable |
| `/fcd check` | what this client's API actually offers |
| `/fcd help` | full list |

Any output longer than one line opens in a window you can copy from, rather
than going to chat.

---

## Honestly

**Not every client can do everything.** Each function needed is looked up
individually; if one is missing, only the feature built on it falls away — not
the addon. `/fcd check` shows that probe as a list. If a client protects
cooldown values, for instance, nobody can detect the end of a cooldown, and
ready alerts show up as missing.

**Instant is possible — on a bar of your own.** Blizzard's categories can be
written two ways, and both have a catch: through their data model it applies
at once but taints their viewer, which then throws errors on target and aura
events until the next `/reload`; through `SetLayoutData` nothing is tainted
but it only applies on reload. The latter is the default.

The way out is the *mirror* button on a section heading: it creates a bar of
your own showing exactly that category. We draw it, so a move shows up there
in the same second — no reload, no call on Blizzard's objects, and therefore
no error message at all. Blizzard's own bars still catch up only on reload;
so FCD asks once, on your first login, whether to switch them off. One
click, reversible at any time with `/fcd solo off`. It flips the same switch
you would find in the game options; the addon does not touch their frames,
because that would be exactly the taint this route avoids.

**Switching layouts only works in their window.** Their layout manager is
protected; calling it from outside would taint the session. `/fcd blizz`
fetches their window for that.

**Settings ride in Blizzard's layout.** The Forever client does not create
SavedVariables for this addon — demonstrated across several sessions. What
does persist is their own layout store, so Forever Cooldowns writes the data
there as well. Side effect: it travels with the same layout as Blizzard's own
settings.

**Before every write** the addon checks that the layout blob survives our
encoding chain intact, and takes a backup. `/fcd restore` undoes the last one.

---

## Links

- Source, issues and full documentation: <https://github.com/Ego26/ForeverCooldowns>
- No dependencies, no libraries — Blizzard API only.
- Licence: MIT
