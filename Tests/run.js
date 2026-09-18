// Fuehrt logic_test.lua in einem echten Lua-VM aus (fengari).
// Getestet wird nur Logik ohne WoW-API: Serialisierer, Import, Rangaufloesung,
// Katalogfilter. Alles andere braucht den laufenden Client.
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

process.chdir(__dirname);

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

const file = process.argv[2] || 'logic_test.lua';
const code = fs.readFileSync(path.join(__dirname, file), 'utf8');
const status = lauxlib.luaL_dostring(L, to_luastring(code));

if (status !== lua.LUA_OK) {
    console.error('LUA-FEHLER: ' + lua.lua_tojsstring(L, -1));
    process.exit(1);
}
