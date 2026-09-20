*Deutsch · [English](CHANGELOG.en.md)*

# Changelog

Alle nennenswerten Änderungen an Forever Cooldowns.

## [0.2.0-beta]

### Hinzugefügt

- **Gespiegelte Leisten.** Eine eigene Leiste kann eine von Blizzards
  Kategorien zeigen; ihren Inhalt bestimmt dieselbe Zuordnung, die das Panel
  bearbeitet. Gezeichnet wird von uns, deshalb steht eine Verschiebung dort
  sofort - ohne Neuladen und ohne einen einzigen Aufruf auf Blizzards
  Objekten, also ohne Taint und ohne Lua-Fehler. Der Knopf *spiegeln* sitzt
  an jeder Abschnittsüberschrift, dazu `/fcd mirror`.
- *Spiegelung lösen* im Leistenfenster: schreibt den jetzigen Bestand fest,
  danach ist es eine gewöhnliche Leiste.
- `/fcd mirror hide` erklärt, wie man Blizzards eigene Leisten ausblendet -
  in ihrem Fenster, weil jedes Anfassen von unserer Seite genau den Taint
  erzeugen würde, den dieser Weg vermeidet.

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
- Der Neuladen-Knopf und die Zustandszeile im Panel unterscheiden jetzt, ob
  eine Änderung überhaupt noch aussteht oder nur noch Blizzards eigene
  Leisten nachziehen müssen.
- Die Kategorienamen liegen nur noch an einer Stelle (`Mirror.lua`); Panel
  und Leisten können sie deshalb nicht mehr verschieden benennen.

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
  Wert schützt, wurde einmal beim Anmelden an irgendeinem Zauber geprüft. Das
  ist die falsche Frage: geschützt ist der einzelne Wert, nicht der Client -
  eine Abklingzeit von null kommt als gewöhnliche Zahl, eine laufende
  geschützt. War der Probezauber gerade bereit, hielt das AddOn alle Werte
  für lesbar und warf beim ersten Vergleich einen Fehler. Jetzt wird bei
  jedem Wert neu gefragt; betrifft Abklingzeiten, Auren, Aufladungen und
  "benutzbar".
- **Geschützte Abklingzeit-Werte bringen kein Symbol mehr zum Fehler.** Sie
  auch nur an die Blizzard-Uhr weiterzureichen lehnt dieser Client ab
  ("Secret values are only allowed during untainted execution"). Der Versuch
  wird jetzt einmal unternommen und beim ersten Nein nicht wiederholt; das
  Symbol bleibt dann ohne Wischer und ohne Restzeit stehen. `/fcd check`
  sagt, welcher der beiden Fälle vorliegt.
- Die Prüfung auf geschützte Werte läuft über mehrere Zauber statt über
  einen. Ein einzelner, der gerade bereit war, hat sie zuverlässig
  danebengehen lassen.
- Eine Leiste, die Blizzards Kategorie "Gegenstände" spiegelt, wurde nicht
  mehr mit der eigenen Gegenstandsleiste verwechselt und umbenannt.

## [0.1.0-beta]

### Hinzugefügt

- Panel zum Bearbeiten von Blizzards Abklingzeit-Kategorien, schmal neben
  ihrem Fenster oder breit mit Werkzeugspalte.
- Rang-Stapelung mit Anzeige des besten gelernten Rangs, Downranking auf
  einen festen Rang.
- Eigene Reiter für beliebige Zauber und für benutzbare Gegenstände.
  Aufnehmen über den Knopf neben der Suche, per `/fcd spell <ID>` oder durch
  Ablegen aus der Tasche - auch Zauber, die im Zauberbuch nicht stehen.
- Übernahme von Blizzards Abklingzeit-Fenster (`/fcd replace on|off`): FCD
  tritt an seine Stelle, ohne dass ihres dabei aufblitzt.
- Übernahme ihrer Einstellungsfenster im Bearbeitungsmodus
  (`/fcd editui on|off`). Gelesen und geschrieben wird über ihren eigenen
  Weg, ihr "Änderungen speichern" sichert mit.
- Fertig-Meldung: Aufleuchten beim Übergang, danach dauerhaft markiert
  solange bereit, wahlweise mit Ton. Benutzt Blizzards Spell-Alert-Leuchten,
  wo der Client es kennt. Einstellbar je Leiste und abweichend je Eintrag.
- Eigene Leisten mit Optionsfenster im Stil des Bearbeitungsmodus:
  Ausrichtung, Spalten, Größe, Abstand, Transparenz, Sichtbarkeit
  einschließlich "Nie", Tooltips, "Beim Anklicken benutzen".
- Layout-Profile mit Import und Export als Text, optionaler Profilwechsel bei
  Haltung, Form oder Spezialisierung.
- Zwei Schreibwege für Blizzards Kategorien: sofort wirksam über ihr
  Datenmodell oder sicher über SetLayoutData. Sicherung vor jedem
  Schreibvorgang, `/fcd restore` nimmt den letzten zurück.
- Zweiter Speicherweg in Blizzards Layout (`Store.lua`), weil dieser Client
  für das AddOn keine SavedVariables anlegt. `/fcd store` schreibt sofort
  und liest gegen.
- Abgerundete Symbolecken über eine Maske (`/fcd round on|off`).
- Diagnosebefehle: `/fcd check`, `/fcd probe`, `/fcd log`, `/fcd layout`,
  `/fcd shown`, `/fcd editmode`, `/fcd editsettings`.

### Bekannte Einschränkungen

- Blizzards Layout lässt sich nur in ihrem eigenen Fenster wechseln
  (`/fcd blizz`); ihr Layoutverwalter ist geschützt.
- Der Sofortmodus markiert Blizzards Viewer als tainted; ihr Aurenzugriff
  scheitert dann bis zum nächsten Neuladen.
- In diesem Client werden die SavedVariables des AddOns nicht zurückgegeben.
  Der Bestand hängt deshalb an Blizzards Layout; schreibt der Client dieses
  Layout selbst neu, kann er dabei verlorengehen. Es wird regelmäßig
  geprüft und nachgetragen.
- Schützt ein Client die Abklingzeit-Werte, ist das Ende einer Abklingzeit
  nicht erkennbar und die Fertig-Meldung entfällt. `/fcd check` sagt, ob das
  hier der Fall ist.
