# Changelog

Alle nennenswerten Aenderungen an Forever Cooldowns.

## [0.1.0-beta]

### Hinzugefuegt

- Panel zum Bearbeiten von Blizzards Abklingzeit-Kategorien, schmal neben
  ihrem Fenster oder breit mit Werkzeugspalte.
- Rang-Stapelung mit Anzeige des besten gelernten Rangs, Downranking auf
  einen festen Rang.
- Eigene Reiter fuer beliebige Zauber und fuer benutzbare Gegenstaende,
  inklusive Ablegen aus der Tasche per Maus.
- Eigene Leisten mit Optionsfenster im Stil des Bearbeitungsmodus; die
  Leisten folgen Blizzards Bearbeitungsmodus.
- Layout-Profile mit Import und Export als Text.
- Zwei Schreibwege fuer Blizzards Kategorien: sofort wirksam ueber ihr
  Datenmodell oder sicher ueber SetLayoutData.
- Sicherungen vor jedem Schreibvorgang, `/fcd restore` nimmt den letzten
  zurueck.
- Diagnosebefehle: `/fcd check`, `/fcd probe`, `/fcd log`, `/fcd layout`.

### Bekannte Einschraenkungen

- Blizzards Layout laesst sich nur in ihrem eigenen Fenster wechseln
  (`/fcd blizz`); ihr Layoutverwalter ist geschuetzt.
- Der Sofortmodus markiert Blizzards Viewer als tainted; ihr Aurenzugriff
  scheitert dann bis zum naechsten Neuladen.
