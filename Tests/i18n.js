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

// Jede Zeichenkette mit Umlaut, die nicht in L[...] steht, ist verdächtig.
// Bewusste Ausnahmen: hier ist Deutsch kein Oberflächentext, sondern ein
// Vergleichswert. Profiles.lua prüft gespeicherte Leistennamen - übersetzt
// man die, findet ein deutsch angelegtes Profil sich auf einem englischen
// Client nicht wieder.
const ERLAUBT = new Set([
    "Gegenstände verfolgen|Profiles.lua",
    "Gegenstände|Profiles.lua",
]);

const GERMAN = /[äöüÄÖÜß]/;
const loose = [];
const used = new Set();

for (const file of files) {
    if (file === 'Locale.lua') continue;
    const text = fs.readFileSync(path.join(root, file), 'utf8');

    for (const m of text.matchAll(/L\["((?:[^"\\]|\\.)*)"\]/g)) {
        used.add(m[1]);
    }

    // Kommentare ausblenden: dort ist Deutsch richtig und gewollt.
    const code = text.replace(/--\[\[[\s\S]*?\]\]/g, '').replace(/--[^\n]*/g, '');
    for (const m of code.matchAll(/(L\[)?"((?:[^"\\]|\\.)*)"/g)) {
        if (m[1]) continue;
        if (!GERMAN.test(m[2])) continue;
        if (ERLAUBT.has(m[2] + "|" + file)) continue;
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
