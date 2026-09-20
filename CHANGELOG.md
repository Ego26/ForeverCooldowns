*Deutsch · [English](CHANGELOG.en.md)*

# Changelog

Alle nennenswerten Änderungen an Forever Cooldowns.

## [0.1.1-beta]

Korrekturfassung. Auf dem Forever-Client zeigte 0.1.0-beta nach einem
Layoutwechsel einen unvollständigen und falsch einsortierten Katalog, und
gespeicherte Daten konnten verlorengehen.

### Behoben

- **Der Katalog kommt jetzt aus Blizzards eigener Anzeigeschicht**
  (`GetDisplayData`). Bisher stammte er aus der Reihenfolgeliste des
  Layouts - die steht in einem frisch angelegten Layout leer, und dann
  schrumpfte das Panel auf die Handvoll gerade aktiver Abklingzeiten,
  während Blizzards Fenster daneben unverändert Hunderte zeigte.
- **Einordnung und "gelernt" stammen aus derselben Quelle.** Die allgemeinen
  Abfragen liefern die globale Vorgabe, nicht den Stand des aktiven Layouts:
  `isInvisible` war dort immer falsch, und `IsSpellKnown` hielt bei
  Rangketten mehrere Ränge für gelernt. Beide Fenster lesen jetzt dieselbe
  Tabelle und zeigen dieselben Abschnitte.
- **Keine Zauber fremder Klassen mehr.** Blizzards Abklingzeit-Addon lädt
  erst bei Bedarf; ohne es fiel der Katalog auf einen Durchlauf über alle
  Klassen zurück. Es wird jetzt selbst angestoßen, und der Durchlauf läuft
  nur noch auf `/fcd catalog voll`.
- **Datenverlust beim Anmelden.** Dieser Client gibt die kontoweite Datei
  nicht immer zurück, obwohl sie gültig auf der Platte liegt; beim Abmelden
  wurde dann der Vorgabestand darüber geschrieben. Die charakterbezogene
  Zweitablage, die das auffangen sollte, war in der `.toc` nicht angemeldet
  und wurde nie beschrieben. Beides behoben, prüfbar mit `/fcd mirror`.
- **Gegenstände kamen nach einem `/reload` zurück.** Die Sperre gegen
  Datenverlust verglich die Größe und hielt damit jedes absichtliche Löschen
  für einen Verlust. Sie prüft jetzt die Herkunft.
- **Änderungen sind sofort zu sehen**, auch wenn der Client sie erst beim
  Neuladen übernimmt. Eine Fähigkeit mit gestapelten Rängen steht nur noch in
  einem Abschnitt, nicht in mehreren.
- **Das Spiel hängt nicht mehr**, wenn viele Abklingzeiten auf einmal
  verschoben werden.
- **Die Filterhaken werden gespeichert** - "nur gelernte" und die übrigen
  standen nach jedem Neuladen wieder auf der Vorgabe.
- **Blizzards Layouts stehen im Auswahlfeld.** Ihr Feld heißt `layoutName`,
  gelesen wurde `name` - die Liste blieb deshalb leer.
- Der Neuladen-Knopf erscheint nur noch, wenn ein Neuladen etwas bewirkt.

### Hinzugefügt

- `/fcd tab` - woraus sich der Reiter zusammensetzt, neben Blizzards Listen.
- `/fcd provider` - Blizzards Datenmodell lesen.
- `/fcd scan` - den Nummernraum der Abklingzeiten durchzählen.
- `/fcd mirror` - Zweitablage schreiben und prüfen.
- `/fcd catalog blizz|voll` - woher die Liste der Abklingzeiten kommt.

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
