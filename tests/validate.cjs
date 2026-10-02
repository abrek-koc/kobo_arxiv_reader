const fs=require('fs');
const path=require('node:path');
const parse=require('luaparse');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const dir=path.join(__dirname, '../arxivreader.koplugin')+path.sep;
for(const name of ['core.lua','main.lua','_meta.lua']){
 parse.parse(fs.readFileSync(dir+name,'utf8'),{luaVersion:'5.1'}); console.log('Lua 5.1 syntax PASS: '+name);
}
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const core=fs.readFileSync(dir+'core.lua','utf8');
const main=fs.readFileSync(dir+'main.lua','utf8');
const tests=String.raw`
local C = (function() CORE_SOURCE end)()
local count=0
local function check(x, name) assert(x,name) count=count+1 end
check(C.id("2402.08954v2")=="2402.08954v2","modern ID")
check(C.id("hep-th/9901001v3")=="hep-th/9901001v3","legacy ID")
check(C.id("https://arxiv.org/pdf/2402.08954v2.pdf")=="2402.08954v2","PDF URL")
check(not C.id("../../settings"),"reject traversal")
check(not C.id("2402.08954v"),"reject incomplete version")
check(not C.id("2402.08954v0"),"reject zero version")
check(C.filename("hep-th/9901001")=="hep-th_9901001","safe legacy filename")
local decode=function(s) return (s:gsub("&amp;","&"):gsub("&lt;","<")) end
local xml=[[<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><opensearch:totalResults>14</opensearch:totalResults>
<entry><id>http://arxiv.org/abs/2402.08954v2</id><title> A &amp; B
 study </title><summary>Useful abstract</summary><author><name>Jane</name></author><author><name>John</name></author><published>2024-02-14T00:00:00Z</published></entry>
<entry><id>http://arxiv.org/abs/hep-th/9901001v1</id><title>Old paper</title><summary>Old abstract</summary><published>1999-01-01T00:00:00Z</published></entry></feed>]]
local papers,total=C.parse(xml,decode)
check(#papers==2 and total==14,"Atom entries and total")
check(papers[1].title=="A & B study","entities and whitespace")
check(papers[1].authors=="Jane, John","multiple authors")
check(papers[1].published=="2024-02-14","date")
check(not C.parse("<html>Unavailable</html>",decode),"non-feed error")
check(not C.parse('<feed><entry><id>http://arxiv.org/api/errors#query</id><summary>Bad query</summary></entry></feed>',decode),"API error")
check(#C.parse("<feed></feed>",decode)==0,"empty feed")
local html=C.html('<html><article class="ltx_document"><h1>Title</h1><math><mi>x</mi></math><img src="x.png"/><script>bad()</script></article></html>',papers[1])
check(html:find("<math>",1,true) and html:find('src="x.png"',1,true),"math and image preservation")
check(not html:find("<script>",1,true),"script removal")
check(not C.html("<html>Not available</html>",papers[1]),"unavailable HTML")
papers[1].notes="A thought\nAnother thought"
check(C.markdown(papers[1]):find("A thought\nAnother thought",1,true),"multiline notes export")

local shown, messages, persisted, opened = {}, {}, {}, nil
local widget={}
function widget:extend(t) setmetatable(t,{__index=self}) return t end
function widget:new(t) return self:extend(t or {}) end
function widget:onShowKeyboard() end
function widget:getInputText() return self.input end
local ui={}
function ui:show(w) shown[#shown+1]=w end
function ui:close(w) end
function ui:forceRePaint() end
local settings={}
function settings:readSetting(k,default) if persisted[k]~=nil then return persisted[k] end return default end
function settings:saveSetting(k,v) persisted[k]=v end
function settings:flush() end
local mods={
 ["ui/widget/container/widgetcontainer"]=widget,
 ["ui/uimanager"]=ui,
 ["ui/widget/menu"]=widget,
 ["ui/widget/textviewer"]=widget,
 ["ui/widget/inputdialog"]=widget,
 ["ui/widget/infomessage"]=widget,
 ["ui/widget/confirmbox"]=widget,
 ["ui/network/manager"]={runWhenConnected=function(_,fn) fn() end},
 ["ui/trapper"]={wrap=function(_,fn) fn() end,clear=function() end},
 ["luasettings"]={open=function() return settings end},
 ["datastorage"]={getSettingsDir=function() return "/settings" end},
 ["device"]={screen={getWidth=function() return 1072 end,getHeight=function() return 1448 end}},
 ["libs/libkoreader-lfs"]={attributes=function() return {mode="file",size=100} end},
 ["util"]={trim=function(s) return s:match("^%s*(.-)%s*$") end,htmlEntitiesToUtf8=decode},
 ["dispatcher"]={registerAction=function() end},
 ["apps/reader/readerui"]={showReader=function(_,path) opened=path end},
}
local oldrequire=require
require=function(name) assert(mods[name],"Unexpected module: "..name) return mods[name] end
dofile=function() return C end
local A=(function() MAIN_SOURCE end)()
A.path = "plugins/arxivreader.koplugin" -- KOReader PluginLoader supplies this field.
local app=A:new{ui={menu={registerToMainMenu=function() end}}}
app:init()
app:onArxivReader()
check(#shown[#shown].item_table==6,"home navigation")
app:remember(papers[1])
check(persisted.papers[papers[1].id].notes=="A thought\nAnother thought","saved paper and notes")
app:notes(papers[1])
local editor=shown[#shown]
editor.input="Updated note\nSecond line"
editor.buttons[1][2].callback()
check(persisted.papers[papers[1].id].notes=="Updated note\nSecond line","edit and save notes")
app:status(papers[1])
shown[#shown].item_table[3].callback()
check(papers[1].status=="Finished","reading status")
app:read(papers[1],"epub")
check(opened=="/mnt/onboard/Articles/2402.08954v2.science-v3.epub" and papers[1].status=="Reading","reader integration")
app:read(papers[1],"pdf")
check(opened=="/mnt/onboard/Articles/2402.08954v2.pdf","PDF reader integration")
app:download(papers[1],"epub")
check(shown[#shown].text:find("Already downloaded",1,true),"existing EPUB download path")
app:download(papers[1],"pdf")
check(shown[#shown].text:find("Already downloaded",1,true),"existing PDF download path")
mods["libs/libkoreader-lfs"].attributes = function(path) return path == "/mnt/onboard/Articles/2402.08954v2.science.epub" and {mode="file"} or nil end
app:read(papers[1],"epub")
check(opened=="/mnt/onboard/Articles/2402.08954v2.science.epub","previous scientific edition remains readable")
mods["libs/libkoreader-lfs"].attributes = function(path) return path == "/mnt/onboard/Articles/2402.08954v2.epub" and {mode="file"} or nil end
app:read(papers[1],"epub")
check(opened=="/mnt/onboard/Articles/2402.08954v2.epub","legacy edition remains readable")
mods["libs/libkoreader-lfs"].attributes = function() return nil end
opened = nil
app:read(papers[1],"epub")
check(not opened and shown[#shown].text:find("Download the EPUB first",1,true),"missing EPUB handled without crash")
app:read(papers[1],"pdf")
check(not opened and shown[#shown].text:find("Download the PDF first",1,true),"missing PDF handled without crash")
app:library(true)
check(#shown[#shown].item_table==1,"notes library")
app:detail(papers[1])
shown[#shown].buttons_table[5][2].callback()
shown[#shown].ok_callback()
check(persisted.papers[papers[1].id]==nil,"remove saved entry")
print("PASS: "..count.." behavioral checks")
`;
const source=tests.replace('CORE_SOURCE',()=>core).replace('MAIN_SOURCE',()=>main);
if(lauxlib.luaL_dostring(L,to_luastring(source))!==lua.LUA_OK){console.error(to_jsstring(lua.lua_tostring(L,-1)));process.exit(1);}

