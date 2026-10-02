const fs=require('node:fs'),path=require('node:path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const parse=require('luaparse');
const root=path.join(__dirname,'..'), dir=path.join(root,'arxivreader.koplugin');
const source=fs.readFileSync(path.join(dir,'scientific.lua'),'utf8');
parse.parse(source,{luaVersion:'5.1'});
const test=String.raw`
local S=(function() SOURCE end)()
local count=0
local function check(v, label) assert(v,label) count=count+1 end
local paper={id="2402.08954v1",title="Math & graphs",authors="A & B"}
local math='<math display="block"><mfrac><mi>a</mi><msqrt><mi>b</mi></msqrt></mfrac></math>'
local html='<html><head></head><body><h2 id="s1">Methods &amp; results</h2><p>Inline <math><mi>x</mi></math>.</p>'
 .. math .. '<figure id="f1"><img src="plot.png" width="400" height="200" style="width:400px" alt="Graph &amp; caption"/>'
 .. '<figcaption>A caption</figcaption></figure><img src="plot.png"/>'
 .. '<svg viewBox="0 0 10 10"><path d="M0 0L10 10"/></svg>'
 .. '<table><tr><td>Cell</td><td>Value</td></tr></table></body></html>'
local decode=function(s) return (s:gsub("&amp;","&")) end
local plan=S.prepare(html,paper,function(h)
 check(not h:find("<math",1,true),"math excluded from HTML balancing")
 return h
end,function(src) return "https://arxiv.org/html/2402.08954v1/"..src end,decode)
check(plan.content:find('<mfrac>',1,true) and plan.content:find('<msqrt>',1,true),"structured math survives")
check(plan.content:find('xmlns="http://www.w3.org/1998/Math/MathML"',1,true),"math namespace")
check(not plan.content:find('width="400"',1,true),"fixed figure sizes removed")
check(plan.content:find("Graph &amp; caption",1,true),"alt text retained and escaped")
check(plan.content:find("<figcaption>A caption",1,true),"caption kept")
check(plan.content:find("<td>Value</td>",1,true),"table content kept")
check(#plan.assets==2,"deduplicate remote figure")
check(plan.assets[1].mime=="image/svg+xml","inline vector extracted")
check(plan.assets[2].url=="https://arxiv.org/html/2402.08954v1/plot.png","relative figure resolution")
check(plan.toc[1].id=="s1" and plan.toc[1].title=="Methods & results","section navigation")
check(S.css:find('@font-face',1,true) and S.css:find("STIX Two Math",1,true),"embedded math typeface")
check(S.imageType("\137PNG\r\n\26\nbytes")=="image/png","PNG")
check(S.imageType("\255\216\255bytes")=="image/jpeg","JPEG")
check(S.imageType('<?xml version="1.0"?><svg xmlns="x"/>')=="image/svg+xml","SVG")
check(not S.imageType("<html>blocked</html>"),"reject HTML masquerading as figure")
local entries, order, requests = {}, {}, 0
S.package(plan,paper,"font","license",function(name,content,stored)
 entries[name]=content order[#order+1]={name,stored}
end,function(url,limit,i,n)
 requests=requests+1
 return "\137PNG\r\n\26\nbytes"
end)
check(requests==1,"one fetch per unique image")
check(order[1][1]=="mimetype" and order[1][2],"EPUB first entry uncompressed")
check(entries["OEBPS/fonts/STIXTwoMath-Regular.otf"]=="font","font packaged")
check(entries["OEBPS/fonts/OFL.txt"]=="license","font license packaged")
check(entries["OEBPS/package.opf"]:find('properties="mathml"',1,true),"EPUB MathML property")
check(entries["OEBPS/nav.xhtml"]:find('article.xhtml#s1',1,true),"navigation target")
check(entries["OEBPS/toc.ncx"]:find('Methods &amp; results',1,true),"legacy TOC escaping")
check(not pcall(function() S.package(plan,paper,"f","l",function() end,function() return nil,"Cancelled." end) end),"cancel aborts package")
check(not pcall(function() S.package(plan,paper,"f","l",function() end,function() return "<html>error</html>" end) end),"invalid image aborts package")
check(not pcall(function() S.prepare('<html><body><img src="bad.png"/></body></html>',paper,function(x)return x end,function()return "https://other.example/x" end,decode) end),"unsupported host explicit")
check(not pcall(function() S.prepare(html,paper,function(x)return x:gsub("ARXIVPROTECTED%d+END","") end,function(src)return "https://arxiv.org/"..src end,decode) end),"missing equation rejected")
-- Simulate disk write failures: no partial file may be promoted.
local removed,renamed=0,0
local writer={open=function()return true end,setZipCompression=function()return true end,
 addFileFromMemory=function()return nil end,close=function()end,err="Disk full"}
require=function(name)
 if name=="libs/libkoreader-cre" then return {getBalancedHTML=function(x)return x end} end
 if name=="socket.url" then return {absolute=function(_,x)return "https://arxiv.org/"..x end} end
 if name=="util" then return {htmlEntitiesToUtf8=decode} end
 if name=="ffi/archiver" then return {Writer={new=function()return writer end}} end
 error(name)
end
io.open=function()return {read=function()return "font" end,close=function()end} end
os.remove=function()removed=removed+1 end
os.rename=function()renamed=renamed+1 return true end
local ok,err=S.create("paper.epub",html,paper,"https://arxiv.org/html/1","plugin",function()return ""end)
check(not ok and removed==1 and renamed==0,"disk failure cleans incomplete EPUB")
writer.addFileFromMemory=function()return true end
ok,err=S.create("paper.epub",html,paper,"https://arxiv.org/html/1","plugin",function()return "\137PNG\r\n\26\n"end)
check(ok and renamed==1,"complete EPUB promoted")
PACKAGED=entries
print("PASS: "..count.." scientific EPUB checks")
`;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
if(lauxlib.luaL_dostring(L,to_luastring(test.replace('SOURCE',()=>source)))!==lua.LUA_OK){
 console.error(to_jsstring(lua.lua_tostring(L,-1)));process.exit(1);
}
const font=fs.readFileSync(path.join(dir,'assets/STIXTwoMath-Regular.otf'));
if(font.toString('ascii',0,4)!=='OTTO')throw Error('Invalid OTF');
fs.mkdirSync(path.join(root,'dist/scientific-test'),{recursive:true});
lua.lua_getglobal(L,to_luastring('PACKAGED'));
lua.lua_pushnil(L);
while(lua.lua_next(L,-2)){
 const name=to_jsstring(lua.lua_tostring(L,-2));
 if(/\.(xhtml|opf|ncx|xml)$/.test(name)){
  const value=to_jsstring(lua.lua_tostring(L,-1));
  const dest=path.join(root,'dist/scientific-test',name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,value);
 }
 lua.lua_pop(L,1);
}
console.log('PASS: bundled OTF signature');
