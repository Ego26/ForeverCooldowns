# Prüfungen

Diese beiden Werkzeuge prüfen das AddOn, ohne dass der Client läuft. Sie sind kein
Ersatz für einen Test im Spiel, fangen aber alles ab, was sonst erst als roter
Lua-Fehler im Chat auffällt.

## Einrichten

```
cd Tests
npm install luaparse fengari
```

## Statische Prüfung

```
node verify.js
```

Prüft alle Lua-Dateien des AddOns auf Syntax (Lua 5.1, wie im Client), auf globale
Referenzen, die weder WoW-API noch AddOn-Global sind (fängt Tippfehler wie
`UnitNam` ab), und darauf, dass jeder modulübergreifende Aufruf eine Definition hat.

## Logiktests

```
node run.js
```

Führt `logic_test.lua` in einem echten Lua-VM aus. Getestet wird, was ohne WoW-API
läuft:

- **Rangparser** — „Rang 4" ergibt 4, „Feuer" und „Passiv" ergeben keinen Rang
- **Rangauflösung** — bester Rang, fester Rang, Rückfall auf den nächstniedrigeren
  gelernten Rang, wenn der gepinnte noch fehlt
- **Export/Import** — Rundlauf mit Sonderzeichen im Namen, Namenskollisionen,
  abgelehnte Fremdtexte und beschädigte Strings
- **Import-Sicherheit** — ein Profilstring, der Code aufzurufen versucht, wird
  abgelehnt und nicht ausgeführt
- **Rückgängig** — Momentaufnahme und Wiederherstellung
- **Katalogfilter** — jede Filterkombination des Editors

Nicht testbar sind Frames, Texturen, Ereignisse und alle `C_*`-Aufrufe. Dafür liegen
`/fcd check` und `/fcd probe` im AddOn selbst.
