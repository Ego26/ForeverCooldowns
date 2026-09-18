*Deutsch · [English](CHANGELOG.en.md)*

# Changelog

Alle nennenswerten Aenderungen an Forever Cooldowns.

## [0.1.0-beta]

### Hinzugefuegt

- Panel zum Bearbeiten von Blizzards Abklingzeit-Kategorien, schmal neben
  ihrem Fenster oder breit mit Werkzeugspalte.
- Rang-Stapelung mit Anzeige des besten gelernten Rangs, Downranking auf
  einen festen Rang.
- Eigene Reiter fuer beliebige Zauber und fuer benutzbare Gegenstaende.
  Aufnehmen ueber den Knopf neben der Suche, per `/fcd spell <ID>` oder durch
  Ablegen aus der Tasche - auch Zauber, die im Zauberbuch nicht stehen.
- Uebernahme von Blizzards Abklingzeit-Fenster (`/fcd replace on|off`): FCD
  tritt an seine Stelle, ohne dass ihres dabei aufblitzt.
- Uebernahme ihrer Einstellungsfenster im Bearbeitungsmodus
  (`/fcd editui on|off`). Gelesen und geschrieben wird ueber ihren eigenen
  Weg, ihr "Aenderungen speichern" sichert mit.
- Fertig-Meldung: Aufleuchten beim Uebergang, danach dauerhaft markiert
  solange bereit, wahlweise mit Ton. Benutzt Blizzards Spell-Alert-Leuchten,
  wo der Client es kennt. Einstellbar je Leiste und abweichend je Eintrag.
- Eigene Leisten mit Optionsfenster im Stil des Bearbeitungsmodus:
  Ausrichtung, Spalten, Groesse, Abstand, Transparenz, Sichtbarkeit
  einschliesslich "Nie", Tooltips, "Beim Anklicken benutzen".
- Layout-Profile mit Import und Export als Text, optionaler Profilwechsel bei
  Haltung, Form oder Spezialisierung.
- Zwei Schreibwege fuer Blizzards Kategorien: sofort wirksam ueber ihr
  Datenmodell oder sicher ueber SetLayoutData. Sicherung vor jedem
  Schreibvorgang, `/fcd restore` nimmt den letzten zurueck.
- Zweiter Speicherweg in Blizzards Layout (`Store.lua`), weil dieser Client
  fuer das AddOn keine SavedVariables anlegt. `/fcd store` schreibt sofort
  und liest gegen.
- Abgerundete Symbolecken ueber eine Maske (`/fcd round on|off`).
- Diagnosebefehle: `/fcd check`, `/fcd probe`, `/fcd log`, `/fcd layout`,
  `/fcd shown`, `/fcd editmode`, `/fcd editsettings`.

### Bekannte Einschraenkungen

- Blizzards Layout laesst sich nur in ihrem eigenen Fenster wechseln
  (`/fcd blizz`); ihr Layoutverwalter ist geschuetzt.
- Der Sofortmodus markiert Blizzards Viewer als tainted; ihr Aurenzugriff
  scheitert dann bis zum naechsten Neuladen.
- In diesem Client werden die SavedVariables des AddOns nicht zurueckgegeben.
  Der Bestand haengt deshalb an Blizzards Layout; schreibt der Client dieses
  Layout selbst neu, kann er dabei verlorengehen. Es wird regelmaessig
  geprueft und nachgetragen.
- Schuetzt ein Client die Abklingzeit-Werte, ist das Ende einer Abklingzeit
  nicht erkennbar und die Fertig-Meldung entfaellt. `/fcd check` sagt, ob das
  hier der Fall ist.
