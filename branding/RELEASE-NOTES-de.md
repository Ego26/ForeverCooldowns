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

- **Lua-Fehler an geschützten Abklingzeit-Werten.** Ob dieser Client einen
  Wert schützt, wurde einmal beim Anmelden an irgendeinem Zauber geprüft -
  geschützt ist aber der einzelne Wert, nicht der Client. War der Zauber
  gerade bereit, hielt das AddOn alle Werte für lesbar und warf bei der
  ersten laufenden Abklingzeit einen Fehler. Jetzt wird je Wert gefragt.
- **Geschützte Abklingzeit-Werte bringen kein Symbol mehr zum Fehler.** Sie
  auch nur an die Blizzard-Uhr weiterzureichen lehnt dieser Client ab
  ("Secret values are only allowed during untainted execution"). Der Versuch
  wird jetzt einmal unternommen und beim ersten Nein nicht wiederholt; das
  Symbol bleibt dann ohne Wischer und ohne Restzeit stehen. `/fcd check`
  sagt, welcher der beiden Fälle vorliegt.
- Die Prüfung auf geschützte Werte läuft über mehrere Zauber statt über
  einen. Ein einzelner, der gerade bereit war, hat sie zuverlässig
  danebengehen lassen.
- Eine Leiste, die Blizzards Kategorie "Gegenstände" spiegelt, wird nicht mehr
  mit der eigenen Gegenstandsleiste verwechselt und umbenannt.
