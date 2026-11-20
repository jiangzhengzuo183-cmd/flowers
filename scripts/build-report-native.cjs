// Native Godot data/assets only. No browser, iframe or JavaScript bridge is used by the game.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),preview=path.resolve(root,'../report-stpageflip-preview'),folder=path.join(root,'godot/assets/report-book');
const full=JSON.parse(fs.readFileSync(path.join(preview,'pages-manifest.json'),'utf8')),catalog=JSON.parse(fs.readFileSync(path.join(root,'godot/data/report_book_catalog.json'),'utf8'));
fs.mkdirSync(path.join(folder,'sources'),{recursive:true});fs.mkdirSync(path.join(folder,'stages'),{recursive:true});
for(const [from,to] of Object.entries({'book-base.png':'book-base.png','closed-cover.png':'closed-cover.png','binding-stack.png':'binding-stack.png','desk-wood.png':'desk-wood.png','blank-left.png':'blank-left.png','blank-right.png':'blank-right.png'}))fs.copyFileSync(path.join(preview,'assets',from),path.join(folder,to));
const reports=full.reports.filter(r=>catalog.entries.some(e=>e.spread===r.id));
const data={design:full.design,reports:[],pages:[],entries:catalog.entries,variants:{},sources:{},artworkRegions:full.artworkRegions};
for(const report of reports){const group=catalog.entries.filter(e=>e.spread===report.id),all=(1<<group.length)-1;data.variants[report.id]={};
 fs.copyFileSync(path.join(preview,'verification/foreground',report.id+'.png'),path.join(folder,'sources',report.id+'.png'));
 data.sources[report.id]={foreground:'res://assets/report-book/sources/'+report.id+'.png',crops:report.crops,transforms:report.transforms};
 data.reports.push({...report,group:group.map(e=>e.id)});
 for(const id of report.pages){const page=full.pages.find(p=>p.id===id);data.pages.push({...page,html:undefined,art:'res://assets/report-book/stages/'+report.id+'-'+all+'-'+page.side+'.png'});}
 for(let mask=1;mask<=all;mask++)data.variants[report.id][mask]={stageIds:group.filter((_,i)=>mask&(1<<i)).map(e=>e.id),left:'res://assets/report-book/stages/'+report.id+'-'+mask+'-left.png',right:'res://assets/report-book/stages/'+report.id+'-'+mask+'-right.png'};
}
fs.writeFileSync(path.join(root,'godot/data/report_book_pages.json'),JSON.stringify(data,null,2));
console.log('Prepared native Godot report data: '+data.reports.length+' spreads / '+data.entries.length+' story events. Run tests/build_report_book_assets.gd to render native textures.');
