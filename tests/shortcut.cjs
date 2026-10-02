const fs = require('node:fs');
const path = require('node:path');
const parse = require('luaparse');
const {lua, lauxlib, lualib, to_luastring, to_jsstring} = require('fengari');
const patch = fs.readFileSync(path.join(__dirname, '../patches/2-arxivreader-shortcut.lua'), 'utf8');
parse.parse(patch, {luaVersion: '5.1'});
const source = String.raw`
local opened, selected, held, notices, checks = 0, 0, 0, 0, 0
local function check(x, label) assert(x,label) checks=checks+1 end
local fc = {
 genItemTable=function() return {{text="Books/",path="/mnt/onboard/Books"}} end,
 onMenuSelect=function() selected=selected+1 end,
 onMenuHold=function() held=held+1 end,
}
local modules = {
 ["ui/widget/filechooser"]=fc,
 ["apps/filemanager/filemanagerutil"]={getHomeFolder=function() return "/mnt/onboard/" end},
 ["ui/uimanager"]={show=function() notices=notices+1 end},
 ["ui/widget/infomessage"]={new=function(_,t) return t end},
}
require=function(name) return assert(modules[name],name) end
PATCH
local fm=setmetatable({name="filemanager",path="/mnt/onboard",ui={
 arxivreader={onArxivReader=function() opened=opened+1 end}
}}, {__index=fc})
local rows=fm:genItemTable({},{},"/mnt/onboard/")
check(#rows==2 and rows[1].text=="arXiv Reader","home row")
fm:onMenuSelect(rows[1])
check(opened==1,"launch app")
fm:onMenuSelect(rows[2])
check(selected==1,"normal selection")
fm:onMenuHold(rows[1])
check(held==0,"shortcut cannot be renamed")
fm:onMenuHold(rows[2])
check(held==1,"ordinary hold")
check(#fm:genItemTable({},{},"/mnt/onboard/Books")==1,"subfolder unchanged")
fm.name="pathchooser"
check(#fm:genItemTable({},{},"/mnt/onboard")==1,"path chooser unchanged")
fm.ui.arxivreader=nil
fm:onMenuSelect(rows[1])
check(notices==1,"disabled plugin message")
-- Simulate another patch already having supplied this exact shortcut.
fm.name="filemanager"
local prior=fc.genItemTable
fc.genItemTable=function(self,...) return {{text="Existing shortcut",path="\0arxivreader-shortcut"}} end
PATCH
check(#fm:genItemTable({},{},"/mnt/onboard")==1,"no duplicate shortcut")
print("PASS: "..checks.." shortcut checks")
`;
const L=lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const code=source.replaceAll('PATCH',()=>patch);
if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK){
 console.error(to_jsstring(lua.lua_tostring(L,-1)));process.exit(1);
}
