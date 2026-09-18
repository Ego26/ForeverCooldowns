# Branding erzeugen

    node brand.js <Pfad zum AddOn-Ordner>              # deutsch
    FCD_LANG=en node brand.js <Pfad zum AddOn-Ordner>  # englisch

Erzeugt:

* `branding/banner-1696-de.png` und `-en.png` (1696x424, CurseForge)
* `branding/icon-512.png`
* `Media/Textures/logo.tga` und `logo-small.tga` (AddOn-Symbol)

## Schrift

Die Wortmarke wird mit **Century Gothic** gesetzt, gelesen direkt aus
`C:/Windows/Fonts/GOTHIC.TTF` und `GOTHICB.TTF`. `ttf.js` ist ein minimaler
TrueType-Leser: Umrisse holen, quadratische Kurven auflösen, nach der
Umlaufregel füllen.

Der Vorgänger zeichnete die Buchstaben selbst, aus Strichen mit runden Enden.
Das sah nach Comic Sans aus, und zwar bauartbedingt - gleichbleibende
Strichstärke und runde Kappen sind genau ihre Merkmale. Sperrung, Größe und
Farbe zu ändern half nicht. Wer das Werkzeug auf einen Rechner ohne Century
Gothic bringt, tauscht die beiden Pfade in `brand.js` gegen eine andere
geometrische Groteske - `bahnschrift.ttf` liegt ebenfalls auf jedem Windows.

## Emblem

Das Emblem ist weiterhin gerechnet, nicht gesetzt: ein Fähigkeitssymbol mit
laufendem Abklingkeil, dahinter zwei versetzte Kacheln als Rangstapel. Es
bleibt auch bei 16 Pixeln lesbar und braucht keine Schrift.
