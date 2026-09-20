// Paket bauen und in den Spielordner spiegeln.
//
// Bislang lief beides von Hand: kopieren, Version ersetzen, zippen. Dabei ist
// genau der Fehler entstanden, der auffiel - im Spielordner stand
// "@project-version@" im Tooltip, weil das Kopieren den Platzhalter nicht
// ersetzt hat. Der gehoert ins Repository, damit der BigWigs-Packager ihn
// beim Bauen fuellt; in jeder ausgelieferten Fassung muss er weg sein.
//
//   node tools/build.js                          # nur das Paket
//   node tools/build.js --sync                   # zusaetzlich in den Spielordner
//   node tools/build.js --version 0.2.0          # andere Version
//
// Der Spielordner steht unten in GAME_PATH; er ist bewusst hier hinterlegt
// und nicht abgefragt, weil dieses Projekt genau einen hat.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const NAME = 'ForeverCooldowns';
const GAME_PATH = 'C:/Spiele/World of Warcraft/_classic_beta_/Interface/AddOns/' + NAME;

// Was ins Paket gehoert. Muss zur ignore-Liste in .pkgmeta passen: was dort
// steht, fehlt hier - Tests, branding, die Punktdateien und die Historie.
const INCLUDE_FILES = ['LICENSE', 'RELEASE-NOTES.md'];
const INCLUDE_DIRS = ['Media'];

function arg(name, fallback) {
    const at = process.argv.indexOf('--' + name);
    if (at < 0) return fallback;
    return process.argv[at + 1] || fallback;
}

const version = arg('version', readVersion());
const sync = process.argv.includes('--sync');

// Die Version steht in Compat.lua als Rueckfall; die .toc traegt den
// Platzhalter, den der Packager fuellt. Eine Quelle statt zweier, die
// auseinanderlaufen koennen.
function readVersion() {
    const compat = fs.readFileSync(path.join(ROOT, 'Compat.lua'), 'utf8');
    const m = compat.match(/FCD\.FALLBACK_VERSION\s*=\s*"([^"]+)"/);
    if (!m) {
        console.error('Keine Version in Compat.lua gefunden (FCD.FALLBACK_VERSION).');
        process.exit(1);
    }
    return m[1];
}

function copyInto(target) {
    fs.mkdirSync(target, { recursive: true });

    for (const file of fs.readdirSync(ROOT)) {
        if (file.endsWith('.lua') || file.endsWith('.toc')) {
            fs.copyFileSync(path.join(ROOT, file), path.join(target, file));
        }
    }
    for (const file of INCLUDE_FILES) {
        const from = path.join(ROOT, file);
        if (fs.existsSync(from)) fs.copyFileSync(from, path.join(target, file));
    }
    for (const dir of INCLUDE_DIRS) {
        const from = path.join(ROOT, dir);
        if (fs.existsSync(from)) fs.cpSync(from, path.join(target, dir), { recursive: true });
    }

    // Der Platzhalter muss in jeder ausgelieferten Fassung weg sein - auch in
    // der Arbeitskopie, sonst steht er im Tooltip der AddOn-Liste.
    const toc = path.join(target, NAME + '.toc');
    fs.writeFileSync(toc,
        fs.readFileSync(toc, 'utf8').replace(/@project-version@/g, version));
}

const stage = path.join(ROOT, '.release', NAME);
fs.rmSync(path.join(ROOT, '.release'), { recursive: true, force: true });
copyInto(stage);

const zip = path.join(ROOT, '.release', NAME + '-' + version + '.zip');
execFileSync('powershell', ['-NoProfile', '-Command',
    'Compress-Archive -Path "' + stage + '" -DestinationPath "' + zip
    + '" -CompressionLevel Optimal -Force']);

const size = (fs.statSync(zip).size / 1024).toFixed(1);
console.log('Paket:  ' + path.relative(ROOT, zip) + '  (' + size + ' KB, Version ' + version + ')');

if (sync) {
    if (!fs.existsSync(path.dirname(GAME_PATH))) {
        console.error('Spielordner nicht gefunden: ' + GAME_PATH);
        process.exit(1);
    }
    copyInto(GAME_PATH);
    console.log('Spiel:  ' + GAME_PATH);
}
