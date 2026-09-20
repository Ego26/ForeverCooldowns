<div align="center">
  <img src="branding/banner-1696-en.png" width="100%"
       alt="Forever Cooldowns – not just Blizzard's list">
</div>

*English · [Deutsch](README.md)*

# Forever Cooldowns

Blizzard's cooldown manager only shows what is on its list. Forever Cooldowns
lifts that limit: **any spell and any usable item** can go on a bar of your
own – and it takes over their entire interface along the way, from the
manager window to the settings dialogs in Edit Mode.

Type `/fcd`.

## What it was built for

**World of Warcraft: Forever** has Blizzard's cooldown manager and, at the
same time, Classic-style spell ranks. Together they make its list useless:
thirty entries that all look alike, because they are the same ability in
thirty ranks.

Forever Cooldowns stacks them into one entry showing the highest rank you
know. Thirty lines become one.

## What it does

**Edit Blizzard's categories.** Select several entries (Ctrl, Shift) and move
them between "Essential", "Utility" and "Hidden" – by dragging or with the
target buttons. Changes land in Blizzard's own layout, not in a parallel
world.

**Any spell or item.** Two tabs of your own, operated exactly like Blizzard's
categories. The "Not in Blizzard's manager" section shows precisely what
their curated list leaves out. The `+` next to the search box takes any spell
or item ID, including things the spellbook does not list; items can also be
dragged in from your bags.

**Ranks.** Rank number on the icon, either always the highest rank you know or
a fixed one (downranking). Learning a new rank needs no follow-up.

**Ready alerts.** When something becomes ready it lights up – using Blizzard's
own spell alert glow where the client has it – and stays marked for as long as
it is ready. Optionally with a sound. Configurable per bar and, via *set per
entry*, differently for individual icons: a silent bar with exactly one
alerting spell is possible, and the other way round.

**One interface for everything.** Forever Cooldowns takes the place of
Blizzard's cooldown window and, in Edit Mode, also replaces the settings
dialogs of **their** bars. The values stay theirs: reading and writing goes
through their own path, their "Save changes" saves ours along with it, and it
survives a reload. Both can be switched off (`/fcd replace off`,
`/fcd editui off`).

The price is the same as for instant mode: writing goes through their
manager into their viewer, which counts as *tainted* afterwards – it
throws errors on target and aura events until the next `/reload`. The
panel says so the first time and offers the reload.

**Your own bars.** Orientation, columns, icon size, spacing, opacity,
visibility (including "Never"), tooltips and "Use on click" – per bar, styled
after their Edit Mode, which the bars follow.

**Profiles.** Save layouts, switch between them, share them as text. Optional
automatic switching on stance, form or specialisation.

## Commands

| Command | Effect |
| --- | --- |
| `/fcd` | open the panel |
| `/fcd wide` | switch between narrow and wide view |
| `/fcd spell <ID>` | add any spell |
| `/fcd replace on\|off` | whether FCD takes the place of their window |
| `/fcd editui on\|off` | our own window in Edit Mode |
| `/fcd blizz` | fetch Blizzard's window (that is where layouts are switched) |
| `/fcd log` | all output, in a copyable window |
| `/fcd check` | what this client's API offers |
| `/fcd help` | full list |

Any output longer than one line opens in a window you can copy from, rather
than going to chat.

## Why every API is probed individually

The Forever client sits between worlds: modern `C_*` namespaces alongside old
globals, plus Classic traits such as spell ranks. So every function needed is
looked up individually and the path that worked is recorded
([`Compat.lua`](Compat.lua)). If one is missing, only the feature built on it
falls away – not the addon.

`/fcd check` shows that probe as a list: what works, what is missing and why.
Some clients protect cooldown values, for instance; then nobody can detect the
end of a cooldown, and ready alerts show up as missing.

## How categories are written

There are two ways, and the addon can do both:

- **Safe mode** (default) through `SetLayoutData`. Taints nothing, but only
  takes effect on reload. The panel offers the reload button for it.
- **Instant mode** (`/fcd instant on`) through Blizzard's own data model. Takes effect
  without reloading. The price: their objects count as *tainted* afterwards,
  and their aura access fails until the next `/reload`. This affects their
  display, not ours.

Before every write, the addon checks that the layout blob survives our
encoding chain losslessly, and takes a backup. `/fcd restore` undoes the last
write.

## Where settings live

Normally in SavedVariables. This client, however, does not create them for the
addon – demonstrated across several sessions, with a valid file, a fully read
`.toc` and a comparison addon for which it does work. What does persist here
is Blizzard's own layout store.

So [`Store.lua`](Store.lua) writes the data there as well. Side effect: it
rides along with the same layout as Blizzard's own settings. On login the
richer of the two sources wins; `/fcd store` writes immediately and reads
back to verify.

## Development

Packaging and mirroring into the game folder is [`tools/build.js`](tools/build.js):

```
node tools/build.js          # package into .release/
node tools/build.js --sync   # and into the game folder
```

It replaces `@project-version@` with the version from `Compat.lua`. The
placeholder belongs in the repository so the packager can fill it - in any
shipped copy it has to be gone, the working copy included.

The checking tools live in [`Tests/`](Tests/) and run without the client:

```
cd Tests
npm install luaparse fengari
node verify.js   # syntax, unknown globals, cross-module calls
node run.js      # logic tests in a real Lua VM
node i18n.js     # German text without L[...], keys without a translation
```

`verify.js` catches exactly the errors that would otherwise first show up as a
red Lua error in chat – typos in globals, calls to functions that do not
exist. `run.js` covers the logic that works without a UI: rank parser, profile
import and export, catalogue filters, layout encoding, and resolving ready
alerts between bar and entry.

Banner and icons are generated, not drawn – see
[`branding/tools/`](branding/tools/).

[`RELEASE-NOTES.md`](RELEASE-NOTES.md) is in English: it goes to CurseForge as
the changelog and ships inside the package. The German version lives in
[`branding/RELEASE-NOTES-de.md`](branding/RELEASE-NOTES-de.md).

## Licence

MIT – see [LICENSE](LICENSE). Use, modify and redistribute freely, as
long as the copyright notice stays with it.
