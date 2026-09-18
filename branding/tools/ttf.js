// Minimaler TrueType-Leser: Umrisse eines Zeichens holen und füllen.
//
// Warum ueberhaupt: die Wortmarke war bisher aus Strichen mit runden Enden
// gebaut. Genau diese Bauweise - gleichbleibende Strichstärke, runde Kappen -
// lässt eine Schrift nach Comic Sans aussehen, und daran aendert kein
// Nachjustieren von Sperrung oder Größe etwas. Eine echte Schrift hat
// gerade Endungen, ausgeglichene Breiten und optische Korrekturen, die man
// von Hand nicht nachbaut.
//
// Gelesen wird nur, was für Versalien gebraucht wird: head, maxp, loca,
// glyf, cmap (Format 4), hhea, hmtx. Zusammengesetzte Zeichen sind
// unterstuetzt, Hinting nicht - das braucht es bei dieser Größe nicht.
const fs = require('fs');

function readFont(path) {
    const buf = fs.readFileSync(path);
    const numTables = buf.readUInt16BE(4);
    const tables = {};
    for (let i = 0; i < numTables; i++) {
        const off = 12 + i * 16;
        tables[buf.toString('ascii', off, off + 4)] = buf.readUInt32BE(off + 8);
    }

    const head = tables.head;
    const unitsPerEm = buf.readUInt16BE(head + 18);
    const longLoca = buf.readInt16BE(head + 50) !== 0;
    const numGlyphs = buf.readUInt16BE(tables.maxp + 4);

    const loca = new Array(numGlyphs + 1);
    for (let i = 0; i <= numGlyphs; i++) {
        loca[i] = longLoca ? buf.readUInt32BE(tables.loca + i * 4)
            : buf.readUInt16BE(tables.loca + i * 2) * 2;
    }

    const numHMetrics = buf.readUInt16BE(tables.hhea + 34);
    function advance(gid) {
        const index = Math.min(gid, numHMetrics - 1);
        return buf.readUInt16BE(tables.hmtx + index * 4);
    }

    // cmap: die Windows-Unicode-Tabelle im Format 4 reicht für Versalien.
    const cmap = tables.cmap;
    let sub = 0;
    const subCount = buf.readUInt16BE(cmap + 2);
    for (let i = 0; i < subCount; i++) {
        const rec = cmap + 4 + i * 8;
        const platform = buf.readUInt16BE(rec), encoding = buf.readUInt16BE(rec + 2);
        if (platform === 3 && (encoding === 1 || encoding === 10)) {
            sub = cmap + buf.readUInt32BE(rec + 4);
        }
    }
    if (!sub) throw new Error('Keine Unicode-Zeichentabelle in ' + path);
    if (buf.readUInt16BE(sub) !== 4) throw new Error('cmap-Format nicht 4 in ' + path);

    const segCount = buf.readUInt16BE(sub + 6) / 2;
    const endAt = sub + 14, startAt = endAt + segCount * 2 + 2;
    const deltaAt = startAt + segCount * 2, rangeAt = deltaAt + segCount * 2;

    function glyphFor(code) {
        for (let i = 0; i < segCount; i++) {
            if (buf.readUInt16BE(endAt + i * 2) < code) continue;
            const start = buf.readUInt16BE(startAt + i * 2);
            if (start > code) return 0;
            const rangeOffset = buf.readUInt16BE(rangeAt + i * 2);
            const delta = buf.readInt16BE(deltaAt + i * 2);
            if (rangeOffset === 0) return (code + delta) & 0xffff;
            const at = rangeAt + i * 2 + rangeOffset + (code - start) * 2;
            const gid = buf.readUInt16BE(at);
            return gid === 0 ? 0 : (gid + delta) & 0xffff;
        }
        return 0;
    }

    // Ein Umriss als Liste von Streckenzuegen, in Schrift-Einheiten.
    function outline(gid, dx, dy, depth) {
        dx = dx || 0; dy = dy || 0; depth = depth || 0;
        if (depth > 4 || loca[gid] === loca[gid + 1]) return [];

        const g = tables.glyf + loca[gid];
        const contourCount = buf.readInt16BE(g);

        if (contourCount < 0) {
            // Zusammengesetzt: Bestandteile mit Versatz einsammeln
            const parts = [];
            let at = g + 10;
            for (;;) {
                const flags = buf.readUInt16BE(at), index = buf.readUInt16BE(at + 2);
                at += 4;
                let ox, oy;
                if (flags & 1) {
                    ox = buf.readInt16BE(at); oy = buf.readInt16BE(at + 2); at += 4;
                } else {
                    ox = buf.readInt8(at); oy = buf.readInt8(at + 1); at += 2;
                }
                if (flags & 8) at += 2;
                else if (flags & 0x40) at += 4;
                else if (flags & 0x80) at += 8;
                for (const c of outline(index, dx + ox, dy + oy, depth + 1)) parts.push(c);
                if (!(flags & 0x20)) break;
            }
            return parts;
        }

        const ends = [];
        for (let i = 0; i < contourCount; i++) ends.push(buf.readUInt16BE(g + 10 + i * 2));
        const pointCount = ends[contourCount - 1] + 1;

        let at = g + 10 + contourCount * 2;
        at += 2 + buf.readUInt16BE(at);          // Hinting überspringen

        const flags = new Array(pointCount);
        for (let i = 0; i < pointCount;) {
            const f = buf.readUInt8(at++);
            flags[i++] = f;
            if (f & 8) {
                let repeat = buf.readUInt8(at++);
                while (repeat-- > 0 && i < pointCount) flags[i++] = f;
            }
        }

        const xs = new Array(pointCount), ys = new Array(pointCount);
        let value = 0;
        for (let i = 0; i < pointCount; i++) {
            const f = flags[i];
            if (f & 2) {
                const d = buf.readUInt8(at++);
                value += (f & 16) ? d : -d;
            } else if (!(f & 16)) {
                value += buf.readInt16BE(at); at += 2;
            }
            xs[i] = value;
        }
        value = 0;
        for (let i = 0; i < pointCount; i++) {
            const f = flags[i];
            if (f & 4) {
                const d = buf.readUInt8(at++);
                value += (f & 32) ? d : -d;
            } else if (!(f & 32)) {
                value += buf.readInt16BE(at); at += 2;
            }
            ys[i] = value;
        }

        const contours = [];
        let first = 0;
        for (const end of ends) {
            const points = [];
            for (let i = first; i <= end; i++) {
                points.push({ x: xs[i] + dx, y: ys[i] + dy, on: (flags[i] & 1) !== 0 });
            }
            first = end + 1;
            const line = flatten(points);
            if (line.length > 2) contours.push(line);
        }
        return contours;
    }

    return { unitsPerEm, glyphFor, advance, outline };
}

// Quadratische Bezier in Strecken auflösen. Zwischen zwei Steuerpunkten
// liegt ein gedachter Kurvenpunkt in der Mitte - das ist die TrueType-Regel,
// ohne die jede zweite Rundung als Ecke herauskaeme.
function flatten(points, steps) {
    steps = steps || 12;
    const n = points.length;
    if (!n) return [];

    const full = [];
    for (let i = 0; i < n; i++) {
        const a = points[i], b = points[(i + 1) % n];
        full.push(a);
        if (!a.on && !b.on) {
            full.push({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, on: true });
        }
    }

    let start = full.findIndex((p) => p.on);
    if (start < 0) return [];
    const seq = full.slice(start).concat(full.slice(0, start));
    seq.push(seq[0]);

    const out = [{ x: seq[0].x, y: seq[0].y }];
    let i = 1;
    while (i < seq.length) {
        const p = seq[i];
        if (p.on) {
            out.push({ x: p.x, y: p.y });
            i += 1;
        } else {
            const from = out[out.length - 1];
            const to = seq[i + 1] || seq[0];
            for (let s = 1; s <= steps; s++) {
                const t = s / steps, mt = 1 - t;
                out.push({
                    x: mt * mt * from.x + 2 * mt * t * p.x + t * t * to.x,
                    y: mt * mt * from.y + 2 * mt * t * p.y + t * t * to.y,
                });
            }
            i += 2;
        }
    }
    return out;
}

// Eine Zeile in eine Deckungsmaske zeichnen.
//
// Gefuellt wird nach der Umlaufregel mit waagerecht exakter und senkrecht
// mehrfach abgetasteter Deckung - das ergibt saubere Kanten ohne die
// Treppchen, die ein reines Ja/Nein pro Pixel hinterlaesst.
//
// Rückgabe: { width, height, cov, capHeight } - cov ist 0..1 je Pixel.
function renderLine(font, text, pixelSize, tracking, pad) {
    pad = pad === undefined ? 4 : pad;
    const scale = pixelSize / font.unitsPerEm;
    const trackUnits = (tracking || 0) * font.unitsPerEm;

    // Erst die Umrisse einsammeln und den tatsächlich belegten Bereich
    // messen. Die Schriftkennwerte taugen dafür nicht: sie beschreiben die
    // ganze Schrift, nicht diese Zeile aus Versalien.
    const contours = [];
    let cursor = 0;
    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    for (const ch of text) {
        const gid = font.glyphFor(ch.codePointAt(0));
        for (const c of font.outline(gid)) {
            const moved = c.map((p) => ({ x: (p.x + cursor) * scale, y: -p.y * scale }));
            for (const p of moved) {
                if (p.x < minX) minX = p.x;
                if (p.x > maxX) maxX = p.x;
                if (p.y < minY) minY = p.y;
                if (p.y > maxY) maxY = p.y;
            }
            contours.push(moved);
        }
        cursor += font.advance(gid) + trackUnits;
    }
    if (!contours.length) {
        return { width: 1, height: 1, cov: new Float32Array(1), capHeight: 0 };
    }

    const width = Math.ceil(maxX - minX) + pad * 2;
    const height = Math.ceil(maxY - minY) + pad * 2;
    const cov = new Float32Array(width * height);

    const edges = [];
    for (const c of contours) {
        for (let i = 0; i < c.length; i++) {
            const a = c[i], b = c[(i + 1) % c.length];
            const ax = a.x - minX + pad, ay = a.y - minY + pad;
            const bx = b.x - minX + pad, by = b.y - minY + pad;
            if (ay !== by) edges.push({ ax, ay, bx, by });
        }
    }

    const SUB = 5;
    const weight = 1 / SUB;
    for (let py = 0; py < height; py++) {
        for (let s = 0; s < SUB; s++) {
            const sy = py + (s + 0.5) / SUB;
            const hits = [];
            for (const e of edges) {
                const low = Math.min(e.ay, e.by), high = Math.max(e.ay, e.by);
                if (sy < low || sy >= high) continue;
                const t = (sy - e.ay) / (e.by - e.ay);
                hits.push({ x: e.ax + t * (e.bx - e.ax), dir: e.by > e.ay ? 1 : -1 });
            }
            if (hits.length < 2) continue;
            hits.sort((a, b) => a.x - b.x);

            let wind = 0, from = 0;
            for (const hit of hits) {
                const before = wind;
                wind += hit.dir;
                if (before === 0 && wind !== 0) from = hit.x;
                else if (before !== 0 && wind === 0) span(cov, width, py, from, hit.x, weight);
            }
        }
    }

    return { width, height, cov, capHeight: maxY - minY };
}

function span(cov, width, py, x0, x1, weight) {
    if (x1 <= x0) return;
    x0 = Math.max(0, x0);
    x1 = Math.min(width, x1);
    if (x1 <= x0) return;

    const row = py * width;
    const first = Math.floor(x0), last = Math.floor(x1 - 1e-9);
    if (first === last) {
        cov[row + first] += (x1 - x0) * weight;
        return;
    }
    cov[row + first] += (first + 1 - x0) * weight;
    for (let x = first + 1; x < last; x++) cov[row + x] += weight;
    cov[row + last] += (x1 - last) * weight;
}

module.exports = { readFont, renderLine };
