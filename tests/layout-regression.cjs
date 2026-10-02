const assert=require('node:assert/strict');
const {prepare,parse5,textContent}=require('./science-harness.cjs');
const walk=(n,tag)=>[...(n.tagName===tag?[n]:[]),...(n.childNodes||[]).flatMap(c=>walk(c,tag))];
const attr=(n,key)=>(n.attrs||[]).find(a=>a.name===key)?.value;
const source='<article><h1>Fixture</h1><figure id="f1"><object type="image/svg+xml" data="2503.01840v3/plot.svg" id="graph"><img src="fallback.png"/></object><figcaption>Figure</figcaption></figure>'
+'<table id="wide" class="ltx_tabular"><tbody><tr><td></td><td></td><td colspan="2">Task A</td><td colspan="2">Task B</td></tr>'
+'<tr><td>Model</td><td>Method</td><td>Speed</td><td><math><mi>x</mi></math></td><td>Speed</td><td><math><mi>x</mi></math></td></tr>'
+'<tr><td colspan="6">Temperature=0</td></tr>'
+'<tr><td rowspan="2">Model A</td><td>First</td><td>1</td><td>2</td><td>3</td><td>4</td></tr>'
+'<tr><td>Second</td><td>5</td><td>6</td><td>7</td><td>8</td></tr></tbody></table></article>';
const p=prepare(source,'2503.01840v3');
assert.equal(p.assets.length,1);
assert.equal(p.assets[0].url,'https://arxiv.org/html/2503.01840v3/plot.svg');
assert.match(p.assets[0].name,/\.svg$/);
assert(!p.content.includes('<object'));
const doc=parse5.parse(p.content),tables=walk(doc,'table');
const panels=tables.filter(t=>attr(t,'class')==='reader-narrow-table');
assert.equal(panels.length,2);
const rows=panels.map(p=>walk(p,'tr').map(r=>(r.childNodes||[]).filter(c=>['th','td'].includes(c.tagName)).map(textContent)));
assert.deepEqual(rows[0][3],['Model A','First','1','2']);
assert.deepEqual(rows[0][4],['Model A','Second','5','6']);
assert.deepEqual(rows[1][3],['Model A','First','3','4']);
assert.deepEqual(rows[1][4],['Model A','Second','7','8']);
assert.equal(tables.length,3); // Original retained, not replaced with an approximation.
assert(p.content.includes('rowspan="2"'));
const ids=[];(function visit(n){const id=attr(n,'id');if(id)ids.push(id);(n.childNodes||[]).forEach(visit);})(doc);
assert.equal(ids.length,new Set(ids).size);
assert(ids.includes('wide'));
const simple=prepare('<article><table class="ltx_tabular"><thead><tr>'+['Method','1','2','4','8','16','32'].map(x=>'<th>'+x+'</th>').join('')+'</tr></thead><tbody><tr>'+['New','1.1','1.2','1.3','1.4','1.5','1.6'].map(x=>'<td>'+x+'</td>').join('')+'</tr></tbody></table></article>','2503.01840v3');
assert.equal(walk(parse5.parse(simple.content),'table').filter(t=>attr(t,'class')==='reader-narrow-table').length,2);
const unknown=prepare('<article><table class="ltx_tabular"><tr>'+Array.from({length:6},(_,i)=>'<td>'+i+'</td>').join('')+'</tr></table></article>','2503.01840v3');
assert(!unknown.content.includes('reader-narrow-table'));
console.log('PASS: SVG objects, grouped headers, rowspan values, source layout, unique IDs, explicit headers, conservative fallback');
