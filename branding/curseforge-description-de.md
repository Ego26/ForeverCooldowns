![Forever Cooldowns](https://raw.githubusercontent.com/Ego26/ForeverCooldowns/main/branding/banner-1696-de.png)

# Forever Cooldowns

**Blizzards Abklingzeit-Manager zeigt nur, was auf seiner Liste steht.
Forever Cooldowns hebt diese Grenze auf.**

Jeder Zauber, jeder benutzbare Gegenstand – auf eine eigene Leiste, mit
denselben Handgriffen wie in ihrem Fenster. Und nicht nur das: Forever
Cooldowns tritt an die Stelle ihres Fensters und ersetzt im Bearbeitungsmodus
auch die Einstellungen ihrer eigenen Leisten.

Tippe `/fcd`.

> **Gebaut für World of Warcraft: Forever.** Jede benötigte Funktion wird
> einzeln geprüft, damit es auch dort läuft, wo ein Client weniger hergibt –
> `/fcd check` zeigt, was deiner kann.
>
> **Auf Deutsch und Englisch.** Die Oberfläche folgt der Sprache deines
> Clients; `/fcd lang de|en|auto` überschreibt das.

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
kuratierte Liste auslässt. Über `+` neben der Suche lässt sich jede Zauber-
oder Gegenstands-ID aufnehmen – auch das, was im Zauberbuch gar nicht steht.
Gegenstände gehen zusätzlich per Ziehen aus der Tasche.

### Melden, wenn bereit

Sobald etwas bereit wird, leuchtet es auf – mit Blizzards eigenem
Spell-Alert-Leuchten, sofern der Client es kennt – und bleibt markiert,
solange es bereit ist. Wahlweise dazu ein Ton, aus einer Liste der Töne, die
dieser Client tatsächlich hat.

Einstellbar pro Leiste und, über **Je Eintrag festlegen**, abweichend für
einzelne Symbole. Eine stumme Leiste mit genau einem meldenden Zauber ist
damit möglich – und umgekehrt genau einer von zwanzig ausgenommen.

### Eine Oberfläche für alles

Forever Cooldowns übernimmt Blizzards Abklingzeit-Fenster, und im
Bearbeitungsmodus auch die Einstellungsfenster **ihrer** Leisten:
Ausrichtung, Symbolgröße, Abstand, Transparenz, Sichtbarkeit.

Die Werte bleiben dabei ihre. Gelesen und geschrieben wird über ihren eigenen
Weg – ihre Oberfläche zieht von selbst nach, ihr „Änderungen speichern"
sichert unsere Änderungen mit, und ein Neuladen überlebt es. Wer lieber ihre
Fenster behält: `/fcd replace off` und `/fcd editui off`.

### Blizzards Kategorien bearbeiten

Mehrere Einträge auswählen (Strg, Umschalt), zwischen *Essenziell*,
*Strategisch* und *Nicht angezeigt* verschieben – per Ziehen oder über die
Zielknöpfe. Geschrieben wird in ihr eigenes Layout, nicht in eine
Parallelwelt.

### Ränge

Rangzahl auf dem Symbol. Wahlweise immer der beste gelernte Rang oder ein
fester (Downranking). Wer einen neuen Rang lernt, muss nichts nachziehen.

### Eigene Leisten

Ausrichtung, Spalten, Symbolgröße, Abstand, Transparenz, Sichtbarkeit
einschließlich *Nie*, Tooltips und *Beim Anklicken benutzen* – pro Leiste, in
einem Fenster im Stil von Blizzards Bearbeitungsmodus. Die Leisten folgen ihm
auch: geht er auf, sind sie verschiebbar und beschriftet.

### Profile

Layouts speichern, wechseln und als Text teilen. Optional automatischer
Wechsel bei Haltung, Form oder Spezialisierung.

---

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/fcd` | Panel öffnen |
| `/fcd wide` | schmale oder breite Ansicht |
| `/fcd spell <ID>` | beliebigen Zauber aufnehmen |
| `/fcd lang de\|en\|auto` | Sprache der Oberfläche |
| `/fcd replace on\|off` | ob FCD an die Stelle ihres Fensters tritt |
| `/fcd editui on\|off` | eigenes Fenster im Bearbeitungsmodus |
| `/fcd blizz` | Blizzards Fenster holen (dort wird das Layout gewechselt) |
| `/fcd log` | alle Ausgaben zum Kopieren |
| `/fcd check` | was dieser Client an API hergibt |
| `/fcd help` | vollständige Liste |

Jede Ausgabe, die länger als eine Zeile ist, erscheint in einem Fenster zum
Kopieren statt im Chat.

---

## Ehrlich gesagt

**Nicht jeder Client kann alles.** Jede benötigte Funktion wird einzeln
gesucht; fehlt eine, entfällt genau das Merkmal, das auf ihr aufbaut – nicht
das AddOn. `/fcd check` zeigt diese Prüfung als Liste. Schützt ein Client zum
Beispiel die Abklingzeit-Werte, ist das Ende einer Abklingzeit für niemanden
erkennbar, und die Fertig-Meldung steht dort als *fehlt*.

**Der Sofortmodus hat einen Preis.** Änderungen an Blizzards Kategorien wirken
ohne Neuladen, weil sie über ihr eigenes Datenmodell laufen. Sobald
AddOn-Code das anfasst, gilt es für die restliche Sitzung als *tainted*, und
ihr Viewer kann keine Auren mehr lesen – bis zum nächsten `/reload`. Betrifft
ihre Anzeige, nicht unsere. Wem das nicht passt: `/fcd instant off` schreibt
sicher, wirkt dann aber erst beim Neuladen.

**Das Layout wechseln geht nur bei ihnen.** Ihr Layoutverwalter ist geschützt;
ein Aufruf von außen würde die Sitzung taintieren. `/fcd blizz` holt ihr
Fenster dafür.

**Die Einstellungen hängen an Blizzards Layout.** Der Forever-Client legt für
dieses AddOn keine SavedVariables an – nachgewiesen über mehrere Sitzungen.
Was hier hält, ist ihr eigener Layout-Speicher, also schreibt Forever
Cooldowns den Bestand zusätzlich dorthin. Nebeneffekt: die Daten wandern mit
demselben Layout mit wie Blizzards eigene Einstellungen.

**Vor jedem Schreibvorgang** wird geprüft, ob der Layout-Blob unsere
Kodierkette verlustfrei übersteht, und eine Sicherung angelegt.
`/fcd restore` nimmt den letzten zurück.

---

## Links

- Quelltext, Fehlermeldungen und vollständige Dokumentation: <https://github.com/Ego26/ForeverCooldowns>
- Keine Abhängigkeiten, keine Bibliotheken – ausschließlich Blizzard-API.
