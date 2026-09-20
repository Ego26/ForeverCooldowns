## Was 0.2.0-beta bringt

### Sofort - und ohne einen einzigen Fehler

Eine Abklingzeit zwischen Blizzards Kategorien zu verschieben ließ bisher die
Wahl zwischen zwei schlechten Hälften: über ihr Lua schreiben und es sofort
sehen, dafür ihren Viewer tainten, der danach bei jedem Ziel- und
Aurenereignis rote Fehler wirft - oder sicher schreiben und auf ein Neuladen
warten.

Die C-Funktion, die beides könnte, `SetCooldownViewerCategorySet`, gibt es in
diesem Client nicht. Diese Fassung geht deshalb einen dritten Weg: **wir
zeichnen die Kategorie selbst.**

- **Gespiegelte Leisten.** Der Knopf *spiegeln* an jeder Abschnittsüberschrift
  im Panel legt eine eigene Leiste an, die genau diese Kategorie zeigt. Weil
  die Leiste unsere ist, steht eine Verschiebung dort in derselben Sekunde -
  kein Neuladen, kein Aufruf auf Blizzards Objekten, also auch kein Fehler.
  `/fcd mirror` tut dasselbe aus dem Chat.
- Alles andere an der Leiste bleibt einstellbar: Ausrichtung, Größe,
  Sichtbarkeit, Fertig-Meldung, auch je einzelnem Eintrag.
- **Spiegelung lösen** im Leistenfenster schreibt den jetzigen Bestand fest;
  danach ist es eine gewöhnliche Leiste, die sich von Hand bearbeiten lässt.
- `/fcd mirror hide` erklärt, wie man Blizzards eigene Leisten ausblendet -
  die ziehen weiterhin erst beim Neuladen nach. Ausblenden muss man sie in
  ihrem Fenster; täte das AddOn es, wäre es genau der Taint, den dieser Weg
  vermeidet.

### Geändert

- Der Neuladen-Knopf und die Zustandszeile unterscheiden jetzt, ob eine
  Änderung überhaupt noch aussteht oder nur noch Blizzards eigene Leisten
  nachziehen müssen.
- Die Kategorienamen liegen nur noch an einer Stelle; Panel und Leisten können
  sie deshalb nicht mehr verschieden benennen.

### Behoben

- Eine Leiste, die Blizzards Kategorie "Gegenstände" spiegelt, wird nicht mehr
  mit der eigenen Gegenstandsleiste verwechselt und umbenannt.
