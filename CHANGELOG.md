*Deutsch · [English](CHANGELOG.en.md)*

# Changelog

Alle nennenswerten Änderungen an Forever Cooldowns.

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
- Zweitablage je Charakter: dieser Client gibt die kontoweite Datei beim
  Anmelden nicht zurück, obwohl sie gültig auf der Platte liegt. Beim
  Abmelden wird deshalb eine vollständige Kopie geschrieben, aus der beim
  nächsten Anmelden wiederhergestellt wird. `/fcd mirror` zeigt sie.
- Der Katalog kommt aus Blizzards eigener Anzeigeschicht. Damit zeigen beide
  Fenster dieselben Einträge in denselben Abschnitten, einschließlich der
  nicht gelernten und der ausgeblendeten.
- Diagnosebefehle: `/fcd check`, `/fcd probe`, `/fcd log`, `/fcd layout`,
  `/fcd shown`, `/fcd editmode`, `/fcd editsettings`, `/fcd tab`,
  `/fcd provider`, `/fcd scan`, `/fcd catalog`.

### Bekannte Einschränkungen

- Blizzards Layout lässt sich nur in ihrem eigenen Fenster wechseln
  (`/fcd blizz`); ihr Layoutverwalter ist geschützt.
- Der Sofortmodus markiert Blizzards Viewer als tainted; ihr Aurenzugriff
  scheitert dann bis zum nächsten Neuladen.
- In diesem Client kommt die kontoweite Datei beim Anmelden leer an,
  obwohl sie gültig auf der Platte liegt. Getragen wird der Bestand deshalb
  von der charakterbezogenen Zweitablage, mit Blizzards Layout als drittem
  Netz. `/fcd mirror` sagt, woher er kam.
- Führt der Client für einen Charakter keine Abklingzeiten, bleiben die
  ersten beiden Reiter leer - Blizzards eigenes Fenster ebenso. Eigene
  Zauber und Gegenstände lassen sich davon unabhängig verfolgen.
- Schützt ein Client die Abklingzeit-Werte, ist das Ende einer Abklingzeit
  nicht erkennbar und die Fertig-Meldung entfällt. `/fcd check` sagt, ob das
  hier der Fall ist.
