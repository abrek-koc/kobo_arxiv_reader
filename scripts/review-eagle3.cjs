// Optional network regression: private cached paper and generated artifacts stay in dist/.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {zipSync}=require('fflate');
const {prepare,parse5,textContent}=require('../tests/science-harness.cjs');
const id='2503.01840v3',url='https://arxiv.org/html/'+id,root=path.join(__dirname,'..');
const out=path.join(root,'dist/eagle3-review');fs.mkdirSync(out,{recursive:true});
const walk=(n,tag)=>[...(n.tagName===tag?[n]:[]),...(n.childNodes||[]).flatMap(c=>walk(c,tag))];
const attr=(n,key)=>(n.attrs||[]).find(a=>a.name===key)?.value;
const text=n=>textContent(n).replace(/\s+/g,' ').trim();
function grid(table){
 const grid=[];let r=0;
 for(const row of walk(table,'tr')){
  grid[r]??=[];let c=0;
  for(const cell of (row.childNodes||[]).filter(n=>['td','th'].includes(n.tagName))){
   while(grid[r][c]!==undefined)c++;
   const cs=Number(attr(cell,'colspan')||1),rs=Number(attr(cell,'rowspan')||1),value=text(cell);
   for(let y=r;y<r+rs;y++){grid[y]??=[];for(let x=c;x<c+cs;x++)grid[y][x]=value;}
   c+=cs;
  }r++;
 }return grid;
}
let last=0;
async function request(address){
 const wait=Math.max(0,3100-(Date.now()-last));if(wait)await new Promise(r=>setTimeout(r,wait));
 last=Date.now();const response=await fetch(address,{signal:AbortSignal.timeout(60000)});
 if(!response.ok)throw Error('HTTP '+response.status+' '+address);
 return Buffer.from(await response.arrayBuffer());
}
(async()=>{
 const cache=path.join(root,'dist/eagle3.html');
 if(!fs.existsSync(cache))fs.writeFileSync(cache,await request(url));
 const html=fs.readFileSync(cache,'utf8'),paperDoc=parse5.parse(html);
 const article=walk(paperDoc,'article')[0];assert(article);
 const expected=[...walk(article,'img').map(n=>attr(n,'src')),...walk(article,'object').map(n=>attr(n,'data'))].map(src=>new URL(src,url).href);
 const plan=prepare(html,id,'EAGLE-3: Scaling up Inference Acceleration of Large Language Models via Training-Time Test');
 assert.deepEqual([...new Set(plan.assets.map(a=>a.url))].sort(),[...new Set(expected)].sort(),'Every source figure must be packaged');
 const converted=parse5.parse(plan.content);
 const originalTables=walk(article,'table').filter(t=>(attr(t,'class')||'').includes('ltx_tabular'));
 const groups=walk(converted,'div').filter(t=>attr(t,'class')==='reader-table-groups');
 for(const group of groups){
  const sourceId=walk(group,'a').map(a=>attr(a,'id')).find(Boolean);
  const source=originalTables.find(t=>attr(t,'id')===sourceId);assert(source,'Original table association');
  const expectedGrid=grid(source);
  const labels=walk(group,'p').filter(n=>attr(n,'class')==='reader-table-label');
  const panels=walk(group,'table');
  panels.forEach((panel,i)=>{
   const [,first,last]=text(labels[i]).match(/Columns (\d+).(\d+) of/);
   const actual=grid(panel);const dataCount=Number(last)-Number(first)+1;
   const contextCount=actual[0].length-dataCount;
   const cols=[...Array(contextCount).keys(),...Array.from({length:dataCount},(_,j)=>Number(first)-1+j)];
   assert.deepEqual(actual,expectedGrid.map(row=>cols.map(c=>row[c])),'Cell values and headers must survive splitting');
  });
 }
 console.log('Source parity PASS: '+expected.length+' figure elements; '+groups.length+' wide tables split with every mapped cell checked.');
 const downloads=new Map();
 for(const asset of plan.assets){
  if(!asset.url)continue;
  const file=path.join(out,'cache',asset.name);fs.mkdirSync(path.dirname(file),{recursive:true});
  if(!fs.existsSync(file))fs.writeFileSync(file,await request(asset.url));
  downloads.set(asset.url,fs.readFileSync(file));
  console.log('Figure cached: '+asset.name);
 }
 const entries=plan.pack(downloads);
 for(const [name,data]of Object.entries(entries)){
  const file=path.join(out,name);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,data);
 }
 const zip={};for(const[name,bytes]of Object.entries(entries))zip[name]=[bytes,{level:name==='mimetype'?0:6}];
 fs.writeFileSync(path.join(root,'dist/'+id+'.science-v3.epub'),zipSync(zip));
 console.log('EPUB written: dist/'+id+'.science-v3.epub');
 if(process.argv.includes('--screenshots')){
  const{chromium}=require('playwright');
  const browser=await chromium.launch({channel:'msedge',headless:true});
  try{
   const page=await browser.newPage({viewport:{width:536,height:724},deviceScaleFactor:2});
   // HTML preview of packaged bytes. Browser rendering is not KOReader validation.
   const preview=path.join(out,'OEBPS/preview.html');fs.writeFileSync(preview,entries['OEBPS/article.xhtml']);
   await page.goto(require('node:url').pathToFileURL(preview).href);
   await page.addStyleTag({content:'body{font-size:19px;padding:14px;} h1{font-size:1.4em;}'});
   await page.evaluate(()=>document.fonts.ready);
   const status=await page.locator('img').evaluateAll(imgs=>imgs.map(i=>({src:i.getAttribute('src'),ok:i.complete&&i.naturalWidth>0})));
   assert(status.every(i=>i.ok),'Every packaged figure must decode');
   await page.locator('[id="S0.F1"]').scrollIntoViewIfNeeded();
   await page.screenshot({path:path.join(out,'figures.png')});
   await page.locator('.reader-table-groups').first().evaluate(el=>el.scrollIntoView({block:'start'}));
   const widths=await page.locator('.reader-narrow-table').evaluateAll(tables=>tables.map(t=>t.getBoundingClientRect().width));
   assert(widths.every(w=>w<=536),'Readable tables must fit the preview viewport');
   await page.screenshot({path:path.join(out,'table.png')});
   console.log('Browser preview PASS: '+status.length+' figures decoded.');
  }finally{await browser.close();}
 }
})().catch(e=>{console.error(e);process.exit(1)});
