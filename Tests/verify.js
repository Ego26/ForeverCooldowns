// Statische Pruefung aller Lua-Dateien des AddOns:
//   1. Syntax (Lua 5.1, wie im Client)
//   2. globale Referenzen, die weder WoW-API noch AddOn-Global sind (Tippfehler)
//   3. modulübergreifende Aufrufe ohne passende Definition
const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

const dir = path.join(__dirname, '..');
const files = fs.readdirSync(dir).filter(f => f.endsWith('.lua')).sort();
const sources = {};
for (const file of files) {
    sources[file] = fs.readFileSync(path.join(dir, file), 'utf8');
}

let problems = 0;
const report = (line) => { console.log(line); problems++; };

// ------------------------------------------------------------------ 1. Syntax
console.log('== Syntax ==');
const trees = {};
for (const [file, src] of Object.entries(sources)) {
    try {
        trees[file] = luaparse.parse(src, { luaVersion: '5.1', scope: true, locations: true });
        console.log('  ok    ' + file);
    } catch (error) {
        report('  FEHLER ' + file + ': ' + error.message);
    }
}

// ------------------------------------------------- 2. Unbekannte globale Namen
const KNOWN = new Set([
    'assert', 'error', 'ipairs', 'pairs', 'next', 'pcall', 'xpcall', 'select', 'tonumber',
    'tostring', 'type', 'unpack', 'rawget', 'rawset', 'setmetatable', 'getmetatable', 'print',
    'string', 'table', 'math', 'os', '_G', 'loadstring', 'collectgarbage', 'date', 'time',
    'strsplit', 'strjoin', 'strtrim', 'wipe', 'tinsert', 'tremove', 'UISpecialFrames',
    'CreateFrame', 'UIParent', 'GameTooltip', 'DEFAULT_CHAT_FRAME', 'GetTime', 'GetCursorPosition',
    'GetCursorInfo', 'ClearCursor', 'CreateColor', 'HideUIPanel', 'ShowUIPanel',
    'GetBuildInfo', 'UnitClass', 'UnitName', 'UnitLevel', 'UnitExists', 'InCombatLockdown',
    'GetLocale',
    'IsControlKeyDown', 'IsShiftKeyDown', 'StaticPopupDialogs', 'StaticPopup_Show', 'ACCEPT',
    'CANCEL', 'C_Timer', 'Enum',
    'C_Spell', 'C_SpellBook', 'C_Item', 'C_Container', 'C_UnitAuras', 'C_CooldownViewer',
    'C_SpecializationInfo', 'C_AddOns', 'GetAddOnMetadata', 'C_CooldownViewer', 'C_EncodingUtil',
    'SLASH_FOREVERCOOLDOWNS1', 'SLASH_FOREVERCOOLDOWNS2', 'SlashCmdList',
    'ForeverCooldowns', 'ForeverCooldownsDB', 'ForeverCooldownsCharDB', 'FCDStore', 'ReloadUI',
]);

const skip = new WeakSet();
function walk(node, callback) {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) { node.forEach(child => walk(child, callback)); return; }
    if (node.type === 'MemberExpression' && node.identifier) skip.add(node.identifier);
    if (node.type === 'TableKeyString' && node.key) skip.add(node.key);
    callback(node);
    for (const key of Object.keys(node)) {
        if (key === 'type' || key === 'loc' || key === 'range') continue;
        walk(node[key], callback);
    }
}

console.log('\n== Globale Referenzen ==');
const unknown = new Map();
for (const [file, tree] of Object.entries(trees)) {
    walk(tree, node => {
        if (node.type !== 'Identifier' || node.isLocal !== false || skip.has(node)) return;
        if (KNOWN.has(node.name)) return;
        if (!unknown.has(node.name)) unknown.set(node.name, new Set());
        unknown.get(node.name).add(file + ':' + node.loc.start.line);
    });
}
if (unknown.size === 0) {
    console.log('  keine unbekannten globalen Referenzen');
} else {
    for (const [name, where] of [...unknown.entries()].sort()) {
        report('  UNBEKANNT ' + name.padEnd(28) + [...where].slice(0, 4).join(', '));
    }
}

// ------------------------------------------------ 3. Modulübergreifende Aufrufe
console.log('\n== Modulaufrufe ==');
const MODULES = ['Compat', 'Profiles', 'Ranks', 'Items', 'Catalog', 'Viewer', 'Editor', 'Probe',
    'Mirror', 'Layout', 'FCD'];
const defs = new Set();
for (const src of Object.values(sources)) {
    for (const m of src.matchAll(/^function\s+(\w+)[.:](\w+)\s*\(/gm)) defs.add(m[1] + '.' + m[2]);
    for (const m of src.matchAll(/^\s*(\w+)\.(\w+)\s*=\s*[^=]/gm)) defs.add(m[1] + '.' + m[2]);
}

const missing = [];
for (const [file, src] of Object.entries(sources)) {
    src.split('\n').forEach((line, index) => {
        if (/^\s*--/.test(line)) return;
        for (const m of line.matchAll(/\bFCD\.(\w+)[.:](\w+)\s*\(/g)) {
            if (MODULES.includes(m[1]) && !defs.has(m[1] + '.' + m[2])) {
                missing.push(`  FEHLT ${file}:${index + 1}  FCD.${m[1]}.${m[2]}`);
            }
        }
        for (const m of line.matchAll(/\bFCD[.:](\w+)\s*\(/g)) {
            if (MODULES.includes(m[1])) continue;
            if (!defs.has('FCD.' + m[1])) missing.push(`  FEHLT ${file}:${index + 1}  FCD.${m[1]}`);
        }
        for (const m of line.matchAll(/\bCompat\.(\w+)\s*\(/g)) {
            if (!defs.has('Compat.' + m[1])) missing.push(`  FEHLT ${file}:${index + 1}  Compat.${m[1]}`);
        }
    });
}
if (missing.length === 0) {
    console.log('  alle modulübergreifenden Aufrufe haben eine Definition');
} else {
    [...new Set(missing)].forEach(report);
}

console.log('\n' + (problems === 0 ? 'Alles in Ordnung.' : problems + ' Beanstandung(en).'));
process.exit(problems === 0 ? 0 : 1);
