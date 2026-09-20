## Was diese Version bringt

Erste öffentliche Fassung.

### Neu

- **Beliebige Zauber und Gegenstände verfolgen.** Blizzards Manager zeigt nur
  seine kuratierte Liste; hier kommt alles auf eine eigene Leiste - über den
  Knopf neben der Suche, per `/fcd spell <ID>` oder durch Ablegen aus der
  Tasche, auch Zauber, die im Zauberbuch nicht stehen. Ein eigener Abschnitt
  zeigt, was ihre Liste auslässt.
- **Ränge gestapelt.** Dieselbe Fähigkeit in dreißig Rängen wird zu einem
  Eintrag mit dem besten gelernten Rang. Rangzahl steht auf dem Symbol.
- **Eine Oberfläche für alles.** Forever Cooldowns tritt an die Stelle von
  Blizzards Abklingzeit-Fenster und ersetzt im Bearbeitungsmodus auch die
  Einstellungsfenster ihrer Leisten. Die Werte bleiben ihre: ihr "Änderungen
  speichern" sichert mit, ein Neuladen überlebt es. Beides abschaltbar.
- **Dieselben Einträge wie ihr Manager.** Der Katalog wird aus ihrer eigenen
  Anzeigeschicht gelesen, deshalb zeigen beide Fenster dieselben
  Abklingzeiten in denselben Abschnitten - einschließlich der noch nicht
  gelernten und der ausgeblendeten.
- **Fertig-Meldung.** Was bereit wird, leuchtet auf und bleibt markiert,
  solange es bereit ist - mit Blizzards eigenem Leuchten, wo der Client es
  kennt. Wahlweise mit Ton, einstellbar je Leiste und abweichend je Eintrag.
- **Blizzards Kategorien bearbeiten.** Mehrfachauswahl, Ziehen zwischen den
  Abschnitten, Zielknöpfe. Geschrieben wird in ihr eigenes Layout.
- **Eigene Leisten** mit Ausrichtung, Größe, Abstand, Transparenz,
  Sichtbarkeit und "Beim Anklicken benutzen" - einstellbar in einem Fenster
  im Stil ihres Bearbeitungsmodus, dem die Leisten auch folgen.
- **Profile** speichern, wechseln und als Text teilen; optional automatisch
  bei Haltung, Form oder Spezialisierung.
- **Oberfläche auf Deutsch und Englisch**, der Sprache des Clients folgend;
  `/fcd lang de|en|auto` überschreibt das.

### Gut zu wissen

`/fcd check` zeigt, was dieser Client hergibt. Jede benötigte API wird
einzeln geprüft - fehlt eine, entfällt genau das Merkmal, das auf ihr
aufbaut, nicht das AddOn.

Dieser Client gibt die gespeicherten Daten des AddOns beim Anmelden nicht
zurück. Forever Cooldowns hält deshalb eine Zweitablage je Charakter und
stellt daraus wieder her; `/fcd mirror` sagt, woher deine Einstellungen kamen.

Führt der Client für einen Charakter überhaupt keine Abklingzeiten, bleiben
die ersten beiden Reiter leer - Blizzards eigenes Fenster ebenso. Eigene
Zauber und Gegenstände lassen sich auf den anderen beiden Reitern trotzdem
verfolgen.
