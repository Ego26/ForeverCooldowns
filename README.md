<div align="center">
  <img src="branding/banner-1696-de.png" width="100%"
       alt="Forever Cooldowns – nicht nur Blizzards Liste">
</div>

*Deutsch · [English](README.en.md)*

# Forever Cooldowns

Blizzards Abklingzeit-Manager zeigt nur, was auf seiner Liste steht. Forever
Cooldowns hebt diese Grenze auf: **jeder Zauber und jeder benutzbare
Gegenstand** kann auf eine eigene Leiste – und übernimmt dabei ihre gesamte
Oberfläche, vom Manager-Fenster bis zu den Einstellungen im
Bearbeitungsmodus.

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
das, was ihre kuratierte Liste auslässt. Über `+` neben der Suche lässt sich
jede Zauber- oder Gegenstands-ID aufnehmen, auch was das Zauberbuch nicht
führt; Gegenstände gehen auch per Ziehen aus der Tasche.

**Ränge.** Rangzahl auf dem Symbol, wahlweise immer der beste gelernte Rang
oder ein fester (Downranking). Wer einen neuen Rang lernt, muss nichts
nachziehen.

**Fertig-Meldung.** Sobald etwas bereit wird, leuchtet es auf – mit Blizzards
eigenem Spell-Alert-Leuchten, sofern der Client es kennt – und bleibt
markiert, solange es bereit ist. Wahlweise dazu ein Ton. Einstellbar pro
Leiste und, über *Je Eintrag festlegen*, abweichend für einzelne Symbole:
eine stumme Leiste mit genau einem meldenden Zauber ist damit möglich, und
umgekehrt.

**Eine Oberfläche für alles.** Forever Cooldowns tritt an die Stelle von
Blizzards Abklingzeit-Fenster und ersetzt im Bearbeitungsmodus auch die
Einstellungsfenster **ihrer** Leisten. Die Werte bleiben ihre: gelesen und
geschrieben wird über ihren eigenen Weg, ihr „Änderungen speichern" sichert
mit, und ein Neuladen überlebt es. Beides abschaltbar (`/fcd replace off`,
`/fcd editui off`).

Der Preis ist derselbe wie beim Sofortmodus: Wir schreiben dabei durch
ihren Verwalter in ihren Viewer, und der gilt danach als *tainted* – er
wirft bis zum nächsten `/reload` Fehler bei Ziel- und Aurenereignissen.
Das Panel sagt es beim ersten Mal und bietet das Neuladen an.

**Eigene Leisten.** Ausrichtung, Spalten, Symbolgröße, Abstand, Transparenz,
Sichtbarkeit (einschließlich „Nie"), Tooltips und „Beim Anklicken benutzen" –
pro Leiste, im Stil ihres Bearbeitungsmodus, dem die Leisten auch folgen.

**Profile.** Layouts speichern, wechseln, als Text teilen. Optional
automatischer Wechsel bei Haltung, Form oder Spezialisierung.

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/fcd` | Panel öffnen |
| `/fcd wide` | zwischen schmaler und breiter Ansicht wechseln |
| `/fcd spell <ID>` | beliebigen Zauber aufnehmen |
| `/fcd replace on\|off` | ob FCD an die Stelle ihres Fensters tritt |
| `/fcd editui on\|off` | eigenes Fenster im Bearbeitungsmodus |
| `/fcd blizz` | Blizzards Fenster holen (dort wird das Layout gewechselt) |
| `/fcd log` | alle Ausgaben zum Kopieren |
| `/fcd check` | was dieser Client an API hergibt |
| `/fcd help` | vollständige Liste |

Jede Ausgabe, die länger als eine Zeile ist, erscheint in einem Fenster zum
Kopieren statt im Chat.

## Warum jede API einzeln geprüft wird

Der Forever-Client liegt zwischen den Welten: moderne `C_*`-Namespaces neben
alten Globals, dazu Classic-Eigenheiten wie Zauberränge. Deshalb wird jede
benötigte Funktion einzeln gesucht und der gefundene Weg festgehalten
([`Compat.lua`](Compat.lua)). Fehlt eine, entfällt genau das Merkmal, das auf
ihr aufbaut – nicht das AddOn.

`/fcd check` zeigt diese Prüfung als Liste: was geht, was fehlt und woran es
liegt. Manche Clients schützen zum Beispiel die Abklingzeit-Werte; dann kann
niemand das Ende einer Abklingzeit erkennen, und die Fertig-Meldung steht
dort als *fehlt*.

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

## Wo die Einstellungen liegen

Normalerweise in den SavedVariables. Dieser Client legt sie für das AddOn
allerdings nicht an – nachgewiesen über mehrere Sitzungen, mit gültiger
Datei, vollständig gelesener `.toc` und einem Vergleichs-AddOn, bei dem es
funktioniert. Was hier hält, ist Blizzards eigener Layout-Speicher.

Deshalb schreibt [`Store.lua`](Store.lua) den Bestand zusätzlich dorthin.
Nebeneffekt: die Daten hängen am selben Layout wie Blizzards Einstellungen
und wandern mit ihm mit. Beim Anmelden wird die reichhaltigere der beiden
Quellen genommen, `/fcd store` schreibt sofort und liest gegen.

## Entwicklung

Bauen und in den Spielordner spiegeln erledigt [`tools/build.js`](tools/build.js):

```
node tools/build.js          # Paket nach .release/
node tools/build.js --sync   # zusätzlich in den Spielordner
```

Es ersetzt dabei `@project-version@` durch die Version aus `Compat.lua`. Der
Platzhalter gehört ins Repository, damit der Packager ihn füllt - in jeder
ausgelieferten Fassung muss er weg sein, auch in der Arbeitskopie.

Die Prüfwerkzeuge liegen in [`Tests/`](Tests/) und laufen ohne den Client:

```
cd Tests
npm install luaparse fengari
node verify.js   # Syntax, unbekannte Globals, modulübergreifende Aufrufe
node run.js      # Logiktests in einem echten Lua-VM
node i18n.js     # deutscher Text ohne L[...], Schlüssel ohne Übersetzung
```

`verify.js` fängt genau die Fehler ab, die sonst erst als roter Lua-Fehler im
Chat auffallen – Tippfehler in Globals, Aufrufe auf Funktionen, die es nicht
gibt. `run.js` prüft die Logik, die ohne Oberfläche auskommt: Rangparser,
Profil-Im- und -Export, Katalogfilter, Layout-Kodierung und das Auflösen der
Fertig-Meldung zwischen Leiste und Eintrag.

Banner und Symbole werden erzeugt, nicht gezeichnet – siehe
[`branding/tools/`](branding/tools/).

[`RELEASE-NOTES.md`](RELEASE-NOTES.md) ist englisch: Sie geht als Changelog
an CurseForge und liegt im ausgelieferten Paket. Die deutsche Fassung steht
unter [`branding/RELEASE-NOTES-de.md`](branding/RELEASE-NOTES-de.md).

## Lizenz

MIT – siehe [LICENSE](LICENSE). Benutzen, ändern und weitergeben ist
erlaubt, solange der Copyright-Hinweis erhalten bleibt.
