// Erzeugt Emblem, Symbol und Banner fuer Forever Cooldowns.
//
// Alles gezeichnet statt gesetzt: es gibt hier keine Schriftdatei, also ist
// die Wortmarke aus Strichen mit runden Enden aufgebaut - dieselbe Bauweise
// wie bei einer geometrischen Groteske. Vierfach ueberabgetastet.
const fs = require('fs'), zlib = require('zlib');
const TTF = require('./ttf.js');

// ----------------------------------------------------------------- Farben
const GOLD = [240, 196, 64];
const GOLD_DARK = [214, 158, 40];
const ORANGE = [226, 118, 34];
const WHITE = [248, 246, 242];
const INK = [22, 17, 14];

// ------------------------------------------------------------- Geometrie
function segDist(px, py, x1, y1, x2, y2) {
  const dx = x2 - x1, dy = y2 - y1;
  const len2 = dx * dx + dy * dy;
  let t = len2 ? ((px - x1) * dx + (py - y1) * dy) / len2 : 0;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - (x1 + t * dx), py - (y1 + t * dy));
}

// Kreisbogen als Band. Winkel in Umdrehungen, 0 = rechts, gegen den Uhrzeiger.
function arcDist(px, py, cx, cy, rx, ry, a0, a1) {
  const dx = (px - cx) / rx, dy = (py - cy) / ry;
  let turn = Math.atan2(-dy, dx) / (Math.PI * 2);
  if (turn < 0) turn += 1;
  let inside = a0 <= a1 ? (turn >= a0 && turn <= a1)
                        : (turn >= a0 || turn <= a1);
  if (!inside) {
    // Abstand zu den Enden, damit die Kappen rund bleiben
    const ex = cx + rx * Math.cos(a0 * 2 * Math.PI), ey = cy - ry * Math.sin(a0 * 2 * Math.PI);
    const fx = cx + rx * Math.cos(a1 * 2 * Math.PI), fy = cy - ry * Math.sin(a1 * 2 * Math.PI);
    return Math.min(Math.hypot(px - ex, py - ey), Math.hypot(px - fx, py - fy));
  }
  const scale = (rx + ry) / 2;
  return Math.abs(Math.hypot(dx, dy) - 1) * scale;
}

// ------------------------------------------------------------- Schrift
// Jeder Buchstabe in einer Box der Hoehe 1. Striche und Boegen, runde Enden.
const S = 0.17;                         // Strichstaerke
const G = {};
function letter(name, width, parts) { G[name] = { width, parts }; }

const L = (x1, y1, x2, y2) => ({ t: 'l', x1, y1, x2, y2 });
const A = (cx, cy, rx, ry, a0, a1) => ({ t: 'a', cx, cy, rx, ry, a0, a1 });

letter('A', 0.72, [L(0.05, 1, 0.36, 0), L(0.36, 0, 0.67, 1), L(0.16, 0.66, 0.56, 0.66)]);
letter('B', 0.70, [L(0.10, 0, 0.10, 1), A(0.36, 0.25, 0.28, 0.25, 0.75, 0.25), A(0.36, 0.74, 0.30, 0.26, 0.75, 0.25)]);
letter("C", 0.72, [A(0.40, 0.5, 0.31, 0.5, 0.09, 0.91)]);
letter('D', 0.72, [L(0.10, 0, 0.10, 1), A(0.32, 0.5, 0.33, 0.5, 0.75, 0.25)]);
letter('E', 0.62, [L(0.10, 0, 0.10, 1), L(0.10, 0.02, 0.56, 0.02), L(0.10, 0.5, 0.48, 0.5), L(0.10, 0.98, 0.56, 0.98)]);
letter('F', 0.60, [L(0.10, 0, 0.10, 1), L(0.10, 0.02, 0.56, 0.02), L(0.10, 0.5, 0.46, 0.5)]);
letter("G", 0.76, [A(0.40, 0.5, 0.31, 0.5, 0.09, 0.88), L(0.71, 0.50, 0.71, 0.74), L(0.44, 0.56, 0.71, 0.56)]);
letter('H', 0.74, [L(0.10, 0, 0.10, 1), L(0.64, 0, 0.64, 1), L(0.10, 0.5, 0.64, 0.5)]);
letter('I', 0.26, [L(0.13, 0, 0.13, 1)]);
letter('J', 0.62, [L(0.50, 0, 0.50, 0.72), A(0.30, 0.72, 0.20, 0.26, 0.5, 1.0)]);
letter('K', 0.72, [L(0.10, 0, 0.10, 1), L(0.66, 0, 0.16, 0.54), L(0.30, 0.42, 0.68, 1)]);
letter('L', 0.58, [L(0.10, 0, 0.10, 0.98), L(0.10, 0.98, 0.54, 0.98)]);
letter('M', 0.90, [L(0.10, 1, 0.10, 0), L(0.10, 0, 0.45, 0.62), L(0.45, 0.62, 0.80, 0), L(0.80, 0, 0.80, 1)]);
letter('N', 0.76, [L(0.10, 1, 0.10, 0), L(0.10, 0, 0.66, 1), L(0.66, 1, 0.66, 0)]);
letter('O', 0.80, [A(0.40, 0.5, 0.31, 0.5, 0, 1)]);
letter('P', 0.68, [L(0.10, 0, 0.10, 1), A(0.34, 0.27, 0.30, 0.27, 0.75, 0.25)]);
letter('R', 0.72, [L(0.10, 0, 0.10, 1), A(0.34, 0.27, 0.30, 0.27, 0.75, 0.25), L(0.34, 0.54, 0.66, 1)]);
// S: obere Schale rechts oben beginnend ueber links bis zur Mitte, untere
// Schale von der Mitte ueber rechts und unten nach links. Beide enden in der
// Mitte, sonst klafft die Kurve auf.
letter("S", 0.68, [A(0.36, 0.28, 0.26, 0.26, 0.10, 0.75), A(0.36, 0.72, 0.26, 0.26, 0.60, 0.25)]);
letter('T', 0.66, [L(0.03, 0.02, 0.63, 0.02), L(0.33, 0.02, 0.33, 1)]);
letter('U', 0.76, [L(0.10, 0, 0.10, 0.66), L(0.66, 0, 0.66, 0.66), A(0.38, 0.66, 0.28, 0.32, 0.5, 1.0)]);
letter('V', 0.74, [L(0.06, 0, 0.38, 1), L(0.38, 1, 0.70, 0)]);
letter('W', 1.06, [L(0.05, 0, 0.26, 1), L(0.26, 1, 0.50, 0.24), L(0.50, 0.24, 0.74, 1), L(0.74, 1, 0.96, 0)]);
letter('X', 0.72, [L(0.08, 0, 0.66, 1), L(0.66, 0, 0.08, 1)]);
letter('Y', 0.72, [L(0.08, 0, 0.37, 0.52), L(0.66, 0, 0.37, 0.52), L(0.37, 0.52, 0.37, 1)]);
letter('Z', 0.68, [L(0.08, 0.02, 0.60, 0.02), L(0.60, 0.02, 0.10, 0.98), L(0.10, 0.98, 0.62, 0.98)]);

// Ein fehlender Buchstabe faellt sonst erst im fertigen Bild auf - so wie das
// fehlende J in "NOT JUST BLIZZARDS LIST".
function requireGlyphs(text) {
  for (const ch of text) {
    if (!G[ch]) throw new Error('Kein Zeichen in der Schrift: ' + JSON.stringify(ch));
  }
}
letter(',', 0.28, [L(0.14, 0.86, 0.14, 0.92), L(0.14, 0.92, 0.07, 1.10)]);
letter(' ', 0.40, []);

function textWidth(text, tracking) {
  let w = 0;
  for (const ch of text) w += (G[ch] ? G[ch].width : 0.5) + tracking;
  return w - tracking;
}

// Abstand zum naechsten Strich des Textes, in Einheiten der Versalhoehe.
function textDist(px, py, text, tracking) {
  let cursor = 0, best = 9;
  for (const ch of text) {
    const g = G[ch];
    if (g) {
      for (const p of g.parts) {
        const d = p.t === 'l'
          ? segDist(px - cursor, py, p.x1, p.y1, p.x2, p.y2)
          : arcDist(px - cursor, py, p.cx, p.cy, p.rx, p.ry, p.a0, p.a1);
        if (d < best) best = d;
      }
      cursor += g.width + tracking;
    } else {
      cursor += 0.5 + tracking;
    }
  }
  return best;
}

// ------------------------------------------------------------- Emblem
//
// Ein Ring als Abklingzeit, darin drei gestapelte Kacheln als die
// zusammengefassten Raenge. Der Ring ist zum Teil golden: die laufende
// Abklingzeit. Oben bricht ein Zeiger durch den Ring, damit die Marke nicht
// wie ein reiner Kreis wirkt.
// Ein Faehigkeitssymbol mit laufendem Abklingkeil, dahinter zwei versetzte
// Kacheln als der Stapel gleicher Raenge. Der Keil ueber einem Quadrat ist
// die eindeutigste Bildsprache fuer "Abklingzeit" und bleibt auch bei 16
// Pixeln lesbar - ein Ring mit Kacheln darin war beides nicht.
function roundedBox(px, py, half, radius) {
  const qx = Math.min(Math.max(px, -half + radius), half - radius);
  const qy = Math.min(Math.max(py, -half + radius), half - radius);
  const d = Math.hypot(px - qx, py - qy);
  if (Math.abs(px) > half || Math.abs(py) > half || d > radius) return null;
  return Math.min(half - Math.abs(px), half - Math.abs(py), radius - d);
}

function emblem(u, v) {              // u,v in -1..1, Mittelpunkt 0
  const HALF = 0.62, RAD = 0.20, LINE = 0.075;

  // Der Stapel ragt nach links oben heraus, die vordere Kachel allein waere
  // also nicht die Mitte der Marke. Um die halbe Staffelung verschoben sitzt
  // die Gruppe mittig.
  u -= 0.15;
  v -= 0.15;

  // Stapel dahinter: zwei Kacheln nach links oben versetzt
  for (let i = 2; i >= 1; i--) {
    const off = i * 0.15;
    const inset = roundedBox(u + off, v + off, HALF, RAD);
    if (inset !== null) {
      const front = roundedBox(u + off - 0.15, v + off - 0.15, HALF, RAD);
      if (front === null) {
        if (inset < LINE) return INK;
        return i === 1 ? [198, 146, 44] : [150, 108, 32];
      }
    }
  }

  // Vordere Kachel
  const inset = roundedBox(u, v, HALF, RAD);
  if (inset === null) return null;
  if (inset < LINE) return INK;

  // Abklingkeil: von oben im Uhrzeigersinn, der abgelaufene Teil ist dunkel
  let turn = Math.atan2(-v, u) / (Math.PI * 2);
  if (turn < 0) turn += 1;
  // Ein gutes Drittel abgelaufen: die Kachel bleibt erkennbar golden, der
  // Keil ist deutlich genug, um als Abklingzeit gelesen zu werden.
  const SWEEP = 0.34;
  const done = (0.25 - turn + 1) % 1;

  // Zeiger: eine kraeftige Linie von der Mitte zur Keilkante, dazu eine
  // senkrechte nach oben als Startmarke. Erst damit liest sich der Keil als
  // laufende Zeit und nicht als Ausschnitt.
  const tipAngle = (0.25 - SWEEP) * 2 * Math.PI;
  if (segDist(u, v, 0, 0, Math.cos(tipAngle) * 0.58, -Math.sin(tipAngle) * 0.58) < 0.055) {
    return [255, 232, 150, 255];
  }
  if (segDist(u, v, 0, 0, 0, -0.58) < 0.045) return [255, 232, 150, 255];
  if (Math.hypot(u, v) < 0.075) return [255, 232, 150, 255];

  if (done < SWEEP) {
    return [44, 32, 21, 255];
  }
  return GOLD;
}

// ------------------------------------------------------------- Ausgabe
function supersample(width, height, shade, sub) {
  const px = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < sub; sy++) {
        for (let sx = 0; sx < sub; sx++) {
          const c = shade(x + (sx + 0.5) / sub, y + (sy + 0.5) / sub);
          if (c) { r += c[0] * (c[3] ?? 255); g += c[1] * (c[3] ?? 255); b += c[2] * (c[3] ?? 255); a += (c[3] ?? 255); }
        }
      }
      const at = (y * width + x) * 4;
      px[at] = a ? Math.round(r / a) : 0;
      px[at + 1] = a ? Math.round(g / a) : 0;
      px[at + 2] = a ? Math.round(b / a) : 0;
      px[at + 3] = Math.round(a / (sub * sub));
    }
  }
  return px;
}

function writePNG(file, w, h, px) {
  const raw = Buffer.alloc(h * (w * 4 + 1));
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    px.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  let TBL = null;
  const crc32 = (buf) => {
    if (!TBL) {
      TBL = new Int32Array(256);
      for (let n = 0; n < 256; n++) {
        let c = n;
        for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
        TBL[n] = c;
      }
    }
    let c = -1;
    for (let i = 0; i < buf.length; i++) c = TBL[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
    return c ^ -1;
  };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td) >>> 0);
    return Buffer.concat([len, td, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

function writeTGA(file, size, px) {
  const h = Buffer.alloc(18);
  h[2] = 2; h.writeUInt16LE(size, 12); h.writeUInt16LE(size, 14); h[16] = 32; h[17] = 0x28;
  const body = Buffer.alloc(size * size * 4);
  for (let i = 0; i < size * size; i++) {
    body[i * 4] = px[i * 4 + 2]; body[i * 4 + 1] = px[i * 4 + 1];
    body[i * 4 + 2] = px[i * 4]; body[i * 4 + 3] = px[i * 4 + 3];
  }
  fs.writeFileSync(file, Buffer.concat([h, body]));
}

// ------------------------------------------------------------- Bilder
const base = process.argv[2];

// Symbol: Emblem auf abgerundetem dunklem Grund
function iconShade(size) {
  return (x, y) => {
    const u = (x / size) * 2 - 1, v = (y / size) * 2 - 1;
    const c = emblem(u / 0.86, v / 0.86);
    if (c) return c;
    const m = 0.055, r = 0.17;
    const px = x / size, py = y / size;
    const qx = Math.min(Math.max(px, m + r), 1 - m - r);
    const qy = Math.min(Math.max(py, m + r), 1 - m - r);
    if (px < m || px > 1 - m || py < m || py > 1 - m
      || Math.hypot(px - qx, py - qy) > r) return null;
    const t = (px + py) / 2;
    return [26 + t * 16, 20 + t * 10, 16 + t * 6, 255];
  };
}

for (const [size, name] of [[64, 'logo.tga'], [32, 'logo-small.tga']]) {
  writeTGA(base + '/Media/Textures/' + name, size, supersample(size, size, iconShade(size), 4));
}
writePNG(base + '/branding/icon-512.png', 512, 512, supersample(512, 512, iconShade(512), 4));

// Banner
const BW = 1696, BH = 424;
// Satz mit einer echten Schrift.
//
// Vorher war die Wortmarke aus Strichen mit runden Enden gebaut. Genau diese
// Bauweise laesst eine Schrift nach Comic Sans aussehen, und daran aendert
// kein Nachjustieren von Sperrung oder Groesse etwas - ich habe es dreimal
// versucht. Century Gothic ist eine geometrische Groteske mit geraden
// Endungen und ausgeglichenen Breiten; sie liegt auf jedem Windows.
//
// Gewichtskontrast aus echten Schnitten: die obere Zeile im normalen, die
// untere im fetten Schnitt. Vorher war beides derselbe Strich, nur
// verschieden dick gerechnet.
const FONT_DIR = 'C:/Windows/Fonts/';
const fontRegular = TTF.readFont(FONT_DIR + 'GOTHIC.TTF');
const fontBold = TTF.readFont(FONT_DIR + 'GOTHICB.TTF');

const cap = 104;                                 // beide Hauptzeilen
const cap3 = 30;                                 // Unterzeile
const LINE1 = 'FOREVER', LINE2 = 'COOLDOWNS';
const LINE3 = process.env.FCD_LANG === 'en' ? 'NOT JUST BLIZZARDS LIST' : 'NICHT NUR BLIZZARDS LISTE';

// Die Versalhoehe ist kleiner als die Schriftgroesse; gemessen statt geraten,
// damit beide Zeilen wirklich gleich hoch stehen.
const SIZE = Math.round(cap / 0.72);
const SIZE3 = Math.round(cap3 / 0.72);

const maskTop = TTF.renderLine(fontRegular, LINE1, SIZE, 0.09);
const maskMain = TTF.renderLine(fontBold, LINE2, SIZE, 0.015);

const blockW = Math.max(maskTop.width, maskMain.width);

// Nur die Unterzeile wird auf die Blockbreite gezogen: weite Sperrung ist
// dort die uebliche Form und schliesst den Satz unten ab. Die Sperrung wird
// dafuer gesucht, weil sie sich aus den Vorschubweiten nicht direkt ergibt.
function fitTracking(font, text, size, targetWidth) {
    let low = 0, high = 1.2;
    for (let i = 0; i < 18; i++) {
        const mid = (low + high) / 2;
        if (TTF.renderLine(font, text, size, mid).width < targetWidth) low = mid;
        else high = mid;
    }
    return (low + high) / 2;
}
const maskSub = TTF.renderLine(fontRegular, LINE3, SIZE3,
    fitTracking(fontRegular, LINE3, SIZE3, blockW));

// Anordnung: die beiden Hauptzeilen eng aufeinander, darunter eine duenne
// Linie und die Unterzeile.
const GAP1 = 14, RULE_GAP = 24, RULE_H = 3, GAP2 = 20, EMBLEM_GAP = 84;
const blockH = maskTop.height + GAP1 + maskMain.height
    + RULE_GAP + RULE_H + GAP2 + maskSub.height;
const line1Y = Math.round((BH - blockH) / 2);
const line2Y = line1Y + maskTop.height + GAP1;
const ruleY = line2Y + maskMain.height + RULE_GAP;
const line3Y = ruleY + RULE_H + GAP2;

// Emblem und Schriftblock als eine Gruppe waagerecht ausmitteln.
const emblemR = 132;
const totalW = emblemR * 2 + EMBLEM_GAP + blockW;
const emblemCX = Math.round((BW - totalW) / 2 + emblemR);
const textX = Math.round(emblemCX + emblemR + EMBLEM_GAP);

function bannerShade(x, y) {
  // Emblem links neben dem Schriftblock, mit ihm zusammen ausgemittet
  const c = emblem((x - emblemCX) / emblemR, (y - BH / 2) / emblemR);
  if (c) return c;

  // Hintergrund: warmer Verlauf von links oben nach rechts unten
  const t = (x / BW) * 0.65 + (y / BH) * 0.35;
  let br = 20 + t * 26, bg = 15 + t * 18, bb = 13 + t * 14;

  // Ein flaues Feld aus Abklingzeit-Kacheln gibt dem Grund Tiefe. Dieselbe
  // Formensprache wie das Emblem, damit es nicht wie Dekor von woanders wirkt.
  const CELL = 132;
  const gx = Math.floor(x / CELL), gy = Math.floor(y / CELL);
  const seed = Math.sin(gx * 12.9898 + gy * 78.233) * 43758.5453;
  const jitterX = ((seed % 1) + 1) % 1, jitterY = ((seed * 1.7 % 1) + 1) % 1;
  const cx = gx * CELL + CELL * (0.25 + jitterX * 0.5);
  const cy = gy * CELL + CELL * (0.25 + jitterY * 0.5);
  const size = CELL * (0.26 + jitterX * 0.10);
  const u = (x - cx) / size, v = (y - cy) / size;
  const tile = roundedBox(u, v, 0.62, 0.20);
  if (tile !== null) {
    let turn = Math.atan2(-v, u) / (Math.PI * 2);
    if (turn < 0) turn += 1;
    const done = (0.25 - turn + 1) % 1;
    const sweep = 0.25 + jitterY * 0.5;
    // Der Keil ist heller als die Kachel, damit die Form ablesbar bleibt
    const lift = (tile < 0.06) ? 26 : (done < sweep ? 6 : 17);
    br += lift; bg += lift * 0.78; bb += lift * 0.34;
  }

  // Schleier: nimmt zur Mitte hin zu, wo Emblem und Schrift stehen. Ein
  // flacher Ueberzug wuerde alles gleich dunkel machen - dieser laesst die
  // Raender atmen und haelt die Wortmarke frei.
  const focus = Math.min(1, Math.abs(x - BW * 0.52) / (BW * 0.5));
  const veil = 0.82 - 0.62 * focus;
  const edge = Math.min(1, Math.min(y, BH - y) / (BH * 0.28));
  const shade = 1 - veil * (0.55 + 0.45 * edge);
  return [br * shade + 14 * (1 - shade), bg * shade + 10 * (1 - shade),
    bb * shade + 9 * (1 - shade), 255];
}

// Hintergrund und Emblem zuerst, danach die Schrift daruebergelegt. Getrennt,
// weil die Schrift ihre eigene Kantenglaettung mitbringt - durch den
// Ueberabtaster geschickt wuerde sie ein zweites Mal geglaettet und dadurch
// weich.
const bannerPx = supersample(BW, BH, bannerShade, 3);

function blend(px, width, mask, atX, atY, color) {
  for (let y = 0; y < mask.height; y++) {
    const py = atY + y;
    if (py < 0 || py >= BH) continue;
    for (let x = 0; x < mask.width; x++) {
      const a = mask.cov[y * mask.width + x];
      if (a <= 0.002) continue;
      const px0 = atX + x;
      if (px0 < 0 || px0 >= width) continue;
      const at = (py * width + px0) * 4;
      const k = Math.min(1, a);
      px[at] = Math.round(px[at] * (1 - k) + color[0] * k);
      px[at + 1] = Math.round(px[at + 1] * (1 - k) + color[1] * k);
      px[at + 2] = Math.round(px[at + 2] * (1 - k) + color[2] * k);
    }
  }
}

blend(bannerPx, BW, maskTop, textX, line1Y, GOLD);
blend(bannerPx, BW, maskMain, textX, line2Y, WHITE);
blend(bannerPx, BW, maskSub, textX, line3Y, [186, 170, 146]);

for (let y = ruleY; y < ruleY + RULE_H; y++) {
  for (let x = textX; x < textX + blockW; x++) {
    const at = (y * BW + x) * 4;
    bannerPx[at] = GOLD_DARK[0];
    bannerPx[at + 1] = GOLD_DARK[1];
    bannerPx[at + 2] = GOLD_DARK[2];
  }
}

writePNG(base + (process.env.FCD_LANG === 'en'
  ? '/branding/banner-1696-en.png' : '/branding/banner-1696-de.png'),
  BW, BH, bannerPx);
console.log('fertig');
