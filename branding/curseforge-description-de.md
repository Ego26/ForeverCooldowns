# Forever Cooldowns

**Blizzards Abklingzeit-Manager zeigt nur, was auf seiner Liste steht.
Forever Cooldowns hebt diese Grenze auf.**

Jeder Zauber aus dem Zauberbuch, jeder benutzbare Gegenstand – auf eine
eigene Leiste, mit denselben Handgriffen wie in ihrem Fenster. Dazu ihre
Kategorien bearbeiten, ohne sich durch dreißig identisch aussehende Einträge
zu klicken.

Tippe `/fcd`.

---

## Das Problem, für das es gebaut wurde

In **World of Warcraft: Forever** gibt es Blizzards Abklingzeit-Manager und
gleichzeitig Zauberränge wie in Classic. Zusammen macht das seine Liste
unbrauchbar: dreißig Zeilen, die alle gleich aussehen, weil es dieselbe
Fähigkeit in dreißig Rängen ist.

Forever Cooldowns stapelt sie zu **einem** Eintrag und zeigt den besten
gelernten Rang. Aus dreißig Zeilen wird eine.

---

## Was es kann

### Beliebige Zauber und Gegenstände

Zwei eigene Reiter, gleich bedienbar wie Blizzards Kategorien. Ein Abschnitt
heißt **„Nicht in Blizzards Manager"** und zeigt genau das, was ihre
kuratierte Liste auslässt. Gegenstände lassen sich aus der Tasche direkt auf
das Panel ziehen.

### Blizzards Kategorien bearbeiten

Mehrere Einträge auswählen (Strg, Umschalt), zwischen *Essenziell*,
*Strategisch* und *Nicht angezeigt* verschieben – per Ziehen oder über die
Zielknöpfe. Geschrieben wird in ihr eigenes Layout, nicht in eine
Parallelwelt.

### Ränge

Rangzahl auf dem Symbol. Wahlweise immer der beste gelernte Rang oder ein
fester (Downranking). Wer einen neuen Rang lernt, muss nichts nachziehen.

### Eigene Leisten

Ausrichtung, Spalten, Symbolgröße, Abstand, Transparenz, Sichtbarkeit – pro
Leiste, in einem Fenster im Stil von Blizzards Bearbeitungsmodus. Die Leisten
folgen ihm auch: geht er auf, sind sie verschiebbar und beschriftet.

### Profile

Layouts speichern, wechseln und als Text teilen. Optional automatischer
Wechsel bei Haltung, Form oder Spezialisierung.

---

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/fcd` | Panel öffnen |
| `/fcd wide` | schmale oder breite Ansicht |
| `/fcd blizz` | Blizzards Fenster holen (dort wird das Layout gewechselt) |
| `/fcd log` | alle Ausgaben zum Kopieren |
| `/fcd check` | was dieser Client an API hergibt |
| `/fcd help` | vollständige Liste |

---

## Ehrlich gesagt

**Der Sofortmodus hat einen Preis.** Änderungen wirken ohne Neuladen, weil sie
über Blizzards eigenes Datenmodell laufen. Sobald AddOn-Code das anfasst, gilt
es für die restliche Sitzung als *tainted*, und ihr Viewer kann keine Auren
mehr lesen – bis zum nächsten `/reload`. Betrifft ihre Anzeige, nicht unsere.
Wem das nicht passt: `/fcd instant off` schreibt sicher, wirkt dann aber erst
beim Neuladen.

**Das Layout wechseln geht nur bei ihnen.** Ihr Layoutverwalter ist geschützt;
ein Aufruf von außen würde die Sitzung taintieren. `/fcd blizz` holt ihr
Fenster dafür.

**Vor jedem Schreibvorgang** wird geprüft, ob der Layout-Blob unsere
Kodierkette verlustfrei übersteht, und eine Sicherung angelegt.
`/fcd restore` nimmt den letzten zurück.
