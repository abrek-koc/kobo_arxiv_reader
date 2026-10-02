const fs = require('node:fs');
const path = require('node:path');
const parse5 = require('parse5');
const {lua,lauxlib,lualib,to_luastring,to_jsstring} = require('fengari');
const root=path.join(__dirname,'..');
function textContent(node){return node.nodeName==='#text'?node.value:(node.childNodes||[]).map(textContent).join('');}
function decode(s){return textContent(parse5.parseFragment(s));}
function prepare(html, id, title='Scientific paper') {
 const L=lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
 const push=(name,data)=>{const bytes=typeof data==='string'?to_luastring(data):new Uint8Array(data);lua.lua_pushlstring(L,bytes,bytes.length);lua.lua_setglobal(L,to_luastring(name));};
 const run=code=>{if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));};
 const func=(name,fn)=>{lua.lua_pushjsfunction(L,l=>{const args=[];for(let i=1;i<=lua.lua_gettop(l);i++)args.push(to_jsstring(lua.lua_tostring(l,i)));const result=fn(...args);const bytes=typeof result==='string'?to_luastring(result):new Uint8Array(result);lua.lua_pushlstring(l,bytes,bytes.length);return 1;});lua.lua_setglobal(L,to_luastring(name));};
 func('BALANCE',s=>parse5.serialize(parse5.parse(s)).replace(/<(img|br|hr|meta|link|input|wbr)(\s[^>]*?)?>/g,'<$1$2/>').replaceAll('&nbsp;','&#160;'));
 func('ABSOLUTE',s=>new URL(s,'https://arxiv.org/html/'+id).href);
 func('DECODE',decode);
 push('HTML',html);push('ID',id);push('TITLE',title);
 run('S=(function() '+fs.readFileSync(path.join(root,'arxivreader.koplugin/scientific.lua'),'utf8')+' end)()\nC=(function() '+fs.readFileSync(path.join(root,'arxivreader.koplugin/core.lua'),'utf8')+' end)()\nPAPER={id=ID,title=TITLE,authors=""}\nPLAN=S.prepare(assert(C.html(HTML,PAPER)),PAPER,BALANCE,ABSOLUTE,DECODE)');
 const field=(index,key)=>{lua.lua_getfield(L,index,to_luastring(key));const b=lua.lua_tostring(L,-1);const value=b?to_jsstring(b):null;lua.lua_pop(L,1);return value;};
 lua.lua_getglobal(L,to_luastring('PLAN'));
 const content=field(-1,'content');
 lua.lua_getfield(L,-1,to_luastring('assets'));
 const assets=[];
 for(let i=1;i<=lua.lua_rawlen(L,-1);i++){lua.lua_rawgeti(L,-1,i);assets.push({name:field(-1,'name'),url:field(-1,'url')});lua.lua_pop(L,1);}
 lua.lua_pop(L,2);
 return {content,assets,pack(downloads){
  push('FONT',fs.readFileSync(path.join(root,'arxivreader.koplugin/assets/STIXTwoMath-Regular.otf')));
  push('LICENSE',fs.readFileSync(path.join(root,'arxivreader.koplugin/assets/OFL.txt')));
  const entries={};
  lua.lua_pushjsfunction(L,l=>{
   const name=to_jsstring(lua.lua_tostring(l,1)),bytes=Buffer.from(lua.lua_tostring(l,2));
   entries[name]=bytes;return 0;
  });lua.lua_setglobal(L,to_luastring('ADD'));
  func('FETCH',url=>{if(!downloads.has(url))throw Error('Missing asset '+url);return downloads.get(url);});
  run('S.package(PLAN,PAPER,FONT,LICENSE,ADD,FETCH)');
  return entries;
 }};
}
module.exports={prepare,decode,parse5,textContent};
