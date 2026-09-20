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

- **Gespiegelte Leisten, von Anfang an.** Deine Leisten zeigen genau das, was
  in Blizzards Kategorien liegt. Weil die Leisten unsere sind, steht eine
  Verschiebung dort in derselben Sekunde - kein Neuladen, kein Aufruf auf
  Blizzards Objekten, also auch kein Fehler. Einzuschalten ist nichts; der
  Knopf *spiegeln* an einer Abschnittsüberschrift nimmt weitere Kategorien
  dazu, und `/fcd mirror` tut dasselbe aus dem Chat.
- Alles andere an der Leiste bleibt einstellbar: Ausrichtung, Größe,
  Sichtbarkeit, Fertig-Meldung, auch je einzelnem Eintrag.
- **Spiegelung lösen** im Leistenfenster schreibt den jetzigen Bestand fest;
  danach ist es eine gewöhnliche Leiste, die sich von Hand bearbeiten lässt.
- `/fcd mirror hide` erklärt, wie man Blizzards eigene Leisten ausblendet -
  die ziehen weiterhin erst beim Neuladen nach. Ausblenden muss man sie in
  ihrem Fenster; täte das AddOn es, wäre es genau der Taint, den dieser Weg
  vermeidet.

### Geändert

- **`/fcd solo` schaltet Blizzards eigene Leisten ab.** Sonst stünde alles
  doppelt, sobald FCD ihre Kategorien zeigt. Umgelegt wird der Schalter, den
  auch der Spieler in den Spieloptionen findet (CVar); kennt der Client
  keinen, wird ihr nachladbares AddOn deaktiviert und es wirkt beim nächsten
  Neuladen. Ihre Rahmen werden dabei nicht angefasst - genau das wäre der
  Taint, den dieser Weg vermeidet. Beim ersten Anmelden fragt FCD einmal
  danach; die Antwort ist ein Klick und jederzeit umkehrbar.
- **Die Vorgabeleisten spiegeln Blizzards Kategorien.** Vorher standen dort
  zwei leere Leisten, und sichtbar wurde eine Änderung erst, wenn jemand den
  Knopf "spiegeln" entdeckte. Das kann niemand vorher wissen, also ist es
  jetzt der Anfangszustand: installieren, fertig. Bestehende Profile ziehen
  einmalig nach - aber nur dort, wo die Vorgabeleiste unberührt und leer
  geblieben ist.
- Der Neuladen-Knopf und die Zustandszeile unterscheiden jetzt, ob eine
  Änderung überhaupt noch aussteht oder nur noch Blizzards eigene Leisten
  nachziehen müssen.
- Die Kategorienamen liegen nur noch an einer Stelle; Panel und Leisten können
  sie deshalb nicht mehr verschieden benennen.

### Behoben

- **Gespiegelte Leisten zeigten zu viel.** Der Katalog kennt zu jeder
  Abklingzeit eine Kategorie, auch zu Fähigkeiten, die Blizzards Leisten nie
  anzeigen - "Heldenhafter Stoß" steht unter "Strategisch" und taucht bei
  ihnen trotzdem nirgends auf. Gezeigt wird jetzt, was Blizzard zeigen würde:
  was in ihrer Kategorieliste steht, plus was der Spieler selbst zugewiesen
  hat.
- **Leisten waren in Blizzards Bearbeitungsmodus nicht anzuklicken.** Ihre
  Oberfläche legt eine Fläche über den Bildschirm, die Klicks abfängt. Die
  Leisten steigen jetzt für die Dauer des Bearbeitungsmodus eine Ebene höher -
  dieselbe Behandlung, die das Panel schon hatte.
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
