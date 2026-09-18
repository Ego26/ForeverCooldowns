<div align="center">
  <img src="branding/banner-1696-de.png" width="100%"
       alt="Forever Cooldowns – nicht nur Blizzards Liste">
</div>

# Forever Cooldowns

Blizzards Abklingzeit-Manager zeigt nur, was auf seiner Liste steht. Forever
Cooldowns hebt diese Grenze auf: **jeder Zauber aus dem Zauberbuch und jeder
benutzbare Gegenstand** kann auf eine eigene Leiste – dazu die Bearbeitung
ihrer Kategorien in einem Fenster, das sich bedienen lässt.

Tippe `/fcd`.

## Wofür es gebaut wurde

In **World of Warcraft: Forever** gibt es Blizzards Abklingzeit-Manager und
gleichzeitig Zauberränge wie in Classic. Beides zusammen macht seine Liste
unbrauchbar: dreißig Einträge, die alle gleich aussehen, weil es dieselbe
Fähigkeit in dreißig Rängen ist.

Forever Cooldowns stapelt sie zu einem Eintrag und zeigt den besten gelernten
Rang. Aus dreißig Zeilen wird eine.

## Was es kann

**Blizzards Kategorien bearbeiten.** Mehrere Einträge auswählen (Strg,
Umschalt), zwischen „Essenziell", „Strategisch" und „Nicht angezeigt"
verschieben – per Ziehen oder über die Zielknöpfe. Die Änderungen landen in
Blizzards eigenem Layout, nicht in einer Parallelwelt.

**Beliebige Zauber und Gegenstände.** Zwei eigene Reiter, gleich bedienbar wie
Blizzards Kategorien. Der Abschnitt „Nicht in Blizzards Manager" zeigt genau
das, was ihre kuratierte Liste auslässt. Gegenstände lassen sich aus der
Tasche direkt aufs Panel ziehen.

**Ränge.** Rangzahl auf dem Symbol, wahlweise immer der beste gelernte Rang
oder ein fester (Downranking). Wer einen neuen Rang lernt, muss nichts
nachziehen.

**Eigene Leisten.** Ausrichtung, Spalten, Symbolgröße, Abstand, Transparenz,
Sichtbarkeit – pro Leiste, in einem Fenster im Stil von Blizzards
Bearbeitungsmodus. Die Leisten folgen ihrem Bearbeitungsmodus: geht er auf,
sind sie verschiebbar und beschriftet.

**Profile.** Layouts speichern, wechseln, als Text teilen. Optional
automatischer Wechsel bei Haltung, Form oder Spezialisierung.

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/fcd` | Panel öffnen |
| `/fcd wide` | zwischen schmaler und breiter Ansicht wechseln |
| `/fcd blizz` | Blizzards Fenster holen (dort wird das Layout gewechselt) |
| `/fcd log` | alle Ausgaben zum Kopieren |
| `/fcd check` | was dieser Client an API hergibt |
| `/fcd help` | vollständige Liste |

## Wie die Kategorien geschrieben werden

Es gibt zwei Wege, und das AddOn kann beide:

- **Sofortmodus** (Standard) über Blizzards eigenes Datenmodell. Wirkt ohne
  Neuladen. Der Preis: ihre Objekte gelten danach als *tainted*, ihr
  Aurenzugriff scheitert bis zum nächsten `/reload`. Betrifft ihre Anzeige,
  nicht unsere.
- **Sicherer Modus** (`/fcd instant off`) über `SetLayoutData`. Taintet
  nichts, wirkt aber erst beim Neuladen.

Vor jedem Schreibvorgang wird geprüft, ob der Layout-Blob unsere Kodierkette
verlustfrei übersteht, und eine Sicherung angelegt. `/fcd restore` nimmt den
letzten Schreibvorgang zurück.

## Entwicklung

Die Prüfwerkzeuge liegen in `Tests/` und laufen ohne den Client:

```
cd Tests
npm install luaparse fengari
node verify.js   # Syntax, unbekannte Globals, modulübergreifende Aufrufe
node run.js      # Logiktests in einem echten Lua-VM
```

`verify.js` fängt genau die Fehler ab, die sonst erst als roter Lua-Fehler im
Chat auffallen – Tippfehler in Globals, Aufrufe auf Funktionen, die es nicht
gibt.
