// Prüft die Zweisprachigkeit.
//
// Zwei Fehler fallen sonst erst auf, wenn jemand das AddOn auf Englisch
// benutzt: ein deutscher Text, der nicht durch L läuft, und ein Schlüssel in
// L, für den keine Übersetzung hinterlegt ist. Beides sieht auf einem
// deutschen Client völlig richtig aus.
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const files = fs.readdirSync(root).filter((f) => f.endsWith('.lua'));

const locale = fs.readFileSync(path.join(root, 'Locale.lua'), 'utf8');

// Alle Schlüssel der englischen Tabelle einsammeln.
const translated = new Set();
for (const m of locale.matchAll(/\["((?:[^"\\]|\\.)*)"\]\s*=/g)) {
    translated.add(m[1]);
}

// Beschriftungstabellen auf Dateiebene. Was dort steht, ist ein Schlüssel und
// wird erst beim Anzeigen übersetzt - beim Laden stünde die Sprache noch auf
// der des Clients, und der Text wäre eingebrannt. Für diese Prüfung zählen
// die Werte deshalb als benutzte Schlüssel, nicht als loser Text.
const LABEL_TABLES = {
    'BarOptions.lua': ['ORIENTATION_OPTIONS', 'DIRECTION_OPTIONS', 'GROWTH_OPTIONS',
        'VISIBILITY_OPTIONS', 'ALERT_MODES', 'ENTRY_ALERT_OPTIONS'],
    'BlizzOptions.lua': ['SETTINGS'],
    'Viewer.lua': ['SOUND_CANDIDATES'],
    'Probe.lua': ['FEATURES'],
    'Dock.lua': ['TABS'],
    // Die Kategorienamen sind von Dock.lua hierher gewandert; beide Stellen
    // benutzen dieselbe Tabelle.
    'Mirror.lua': ['CATEGORY_NAMES'],
};

// Bewusste Ausnahmen: hier ist Deutsch kein Oberflächentext, sondern eine
// Kennung. Dock und Profiles vergleichen gespeicherte Leistennamen -
// übersetzt man die, findet ein deutsch angelegtes Profil sich auf einem
// englischen Client nicht wieder.
const KENNUNGEN = new Set([
    'Zauber verfolgen|Dock.lua',
    'Gegenstände verfolgen|Dock.lua',
    'Gegenstände|Dock.lua',
    'Gegenstände verfolgen|Profiles.lua',
    'Gegenstände|Profiles.lua',
]);

const GERMAN = /[äöüÄÖÜß]/;
const POPUP_HEAD = /StaticPopupDialogs\[[^\]]+\]\s*=\s*\{/g;
const POPUP_FIELDS = /\b(text|fcdButton1|fcdButton2)\s*=\s*"((?:[^"\\]|\\.)*)"/g;

const loose = [];
const used = new Set();

for (const file of files) {
    if (file === 'Locale.lua') continue;
    const text = fs.readFileSync(path.join(root, file), 'utf8');

    for (const m of text.matchAll(/L\["((?:[^"\\]|\\.)*)"\]/g)) {
        used.add(m[1]);
    }

    // Die Beschriftungstabellen heraustrennen und ihre Werte als benutzte
    // Schlüssel zählen.
    let rest = text;
    for (const name of LABEL_TABLES[file] || []) {
        const start = rest.indexOf('local ' + name + ' = {');
        if (start < 0) continue;
        const end = rest.indexOf('\n}', start);
        if (end < 0) continue;
        const body = rest.slice(start, end);
        for (const m of body.matchAll(/"((?:[^"\\]|\\.)*)"/g)) {
            if (GERMAN.test(m[1]) || m[1].includes(' ')) used.add(m[1]);
        }
        rest = rest.slice(0, start) + rest.slice(end);
    }

    // Dasselbe für Blizzards Dialoge: sie merken sich ihren Text beim
    // Anlegen, also steht dort ebenfalls der deutsche Schlüssel. Von hinten
    // nach vorn, damit die Stellen sich nicht verschieben.
    for (const m of [...rest.matchAll(POPUP_HEAD)].reverse()) {
        const end = rest.indexOf('\n}', m.index);
        const stop = end < 0 ? rest.length : end;
        const body = rest.slice(m.index, stop).replace(POPUP_FIELDS, (all, field, value) => {
            used.add(value);
            return ' '.repeat(all.length);
        });
        rest = rest.slice(0, m.index) + body + rest.slice(stop);
    }

    // Kommentare ausblenden: dort ist Deutsch richtig und gewollt.
    const code = rest.replace(/--\[\[[\s\S]*?\]\]/g, '').replace(/--[^\n]*/g, '');
    for (const m of code.matchAll(/(L\[)?"((?:[^"\\]|\\.)*)"/g)) {
        if (m[1]) continue;
        if (!GERMAN.test(m[2])) continue;
        if (KENNUNGEN.has(m[2] + '|' + file)) continue;
        const line = code.slice(0, m.index).split('\n').length;
        loose.push(file + ':' + line + '  ' + m[2].slice(0, 60));
    }
}

const missing = [...used].filter((key) => !translated.has(key)).sort();

console.log('== Zweisprachigkeit ==\n');
console.log('Übersetzte Schlüssel: ' + translated.size);
console.log('Im Code benutzt:      ' + used.size);

if (missing.length) {
    console.log('\nOhne englische Fassung (' + missing.length + '):');
    for (const key of missing) console.log('  ' + JSON.stringify(key));
}

if (loose.length) {
    console.log('\nDeutscher Text ohne L[...] (' + loose.length + '):');
    for (const hit of loose) console.log('  ' + hit);
}

if (!missing.length && !loose.length) {
    console.log('\nAlles zweisprachig.');
}
process.exit(missing.length + loose.length > 0 ? 1 : 0);
