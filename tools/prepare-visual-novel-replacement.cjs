#!/usr/bin/env node
// Read-only incoming comparison; --snapshot additionally saves local work under ignored .verification/.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const args=process.argv.slice(2);
if(args.includes('--help')){console.log('node tools/prepare-visual-novel-replacement.cjs [--incoming <local-git-ref>] [--snapshot]');process.exit(0);}
let incoming=null,snapshot=false;
for(let i=0;i<args.length;i++){
 if(args[i]==='--incoming'&&args[i+1])incoming=args[++i];
 else if(args[i]==='--snapshot')snapshot=true;
 else throw Error('Unknown or incomplete option: '+args[i]);
}
function git(...a){return cp.execFileSync('git',a,{cwd:root,maxBuffer:64*1024*1024,stdio:['ignore','pipe','pipe']});}
function text(...a){return git(...a).toString('utf8').trim();}
function resolveRef(ref){return text('rev-parse','--verify','--end-of-options',ref+'^{commit}');}
function parts(buffer){return buffer.toString('utf8').split('\0').filter(Boolean);}
const source=JSON.parse(fs.readFileSync(path.join(root,'godot/modules/visual_novel/source_manifest.json'),'utf8'));
const scopes=['README.md','godot/project.godot','godot/export_presets.cfg','godot/modules/visual_novel','godot/modules/main_menu','godot/modules/loading','godot/modules/game_hud','godot/modules/maze_intro','godot/modules/maze03_final','godot/modules/maze03_race','godot/modules/stamina','godot/modules/maze_items','godot/scenes/levels','godot/scripts/main.gd','godot/scripts/levels','godot/scripts/maze'];
const report={created_utc:new Date().toISOString(),branch:text('branch','--show-current'),head:resolveRef('HEAD'),source:{repository:source.repository,ref:source.ref,commit:source.commit,files:source.files.length},incoming:null,shared_resources:[],local_changes:[],warnings:[]};
const shared=['res://modules/visual_novel/VisualNovel.tscn','res://modules/visual_novel/assets/audio/bakery.ogg','res://modules/visual_novel/assets/audio/paper.mp3','res://modules/visual_novel/assets/fonts/YeLiHangJiuLinKaTong.ttf'];
for(const resource of shared)report.shared_resources.push({resource,exists:fs.existsSync(path.join(root,'godot',resource.slice(6)))});
report.maze03={scene:'res://scenes/levels/Maze03.tscn',implementation:'res://modules/maze03_final/scene.gd',race:'res://modules/maze03_race/controller.gd',configured_mouse_seconds:Number(fs.readFileSync(path.join(root,'godot/modules/maze03_race/default_settings.tres'),'utf8').match(/target_seconds\s*=\s*([0-9.]+)/)[1]),requested_mouse_seconds:55.75};
if(report.maze03.configured_mouse_seconds!==report.maze03.requested_mouse_seconds)report.warnings.push('Current mouse target is '+report.maze03.configured_mouse_seconds+'s; prior user requirement is 55.75s. Reconcile and run timing validation before integration acceptance. No balance values were changed by this audit.');
report.warnings.push('Current story_race adapter does not forward outcome, charlie_time or mouse_time; the new story integration must carry them from the canonical race result.');
report.warnings.push('Loading/audio isolation changes are local work in progress. Preserve them when replacing upstream story scripts.');
const tracked=parts(git('ls-files','--modified','-z','--',...scopes));
const staged=parts(git('diff','--cached','--name-only','-z','--',...scopes));
const untracked=parts(git('ls-files','--others','--exclude-standard','-z','--',...scopes));
const files=[...new Set([...tracked,...staged,...untracked])].sort();
for(const file of files){const absolute=path.resolve(root,file);if(!absolute.startsWith(root+path.sep))throw Error('Path outside repository: '+file);if(!fs.existsSync(absolute)){report.local_changes.push({file,deleted:true});continue;}if(!fs.lstatSync(absolute).isFile())continue;const data=fs.readFileSync(absolute);report.local_changes.push({file,bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex'),untracked:untracked.includes(file)});}
function tree(ref){const map=new Map();for(const entry of parts(git('ls-tree','-rz',ref,'--','godot'))){const at=entry.indexOf('\t');const meta=entry.slice(0,at).split(' ');if(meta[1]==='blob')map.set(entry.slice(at+1),meta[2]);}return map;}
if(incoming){
 const sha=resolveRef(incoming),before=tree(source.commit),after=tree(sha);
 const changes={unchanged:[],modified:[],removed:[],added:[],unmapped_modified:[]};
 const mapped=new Set(source.files.map(f=>f.source));
 for(const item of source.files){const next=after.get(item.source);const kind=!next?'removed':next===before.get(item.source)?'unchanged':'modified';changes[kind].push({source:item.source,target:item.local});}
 const candidates=['godot/scripts/story/','godot/assets/audio/','godot/assets/bakery/','godot/assets/continuation/','godot/assets/experience/','godot/assets/report/','godot/web/ink-observation/assets/'];
 for(const file of after.keys())if(!mapped.has(file)&&!file.endsWith('.uid')&&!file.endsWith('.import')&&(candidates.some(p=>file.startsWith(p))||file.startsWith('godot/data/')&&file.endsWith('.json')&&!file.endsWith('/maze_01.json'))){if(!before.has(file))changes.added.push(file);else if(before.get(file)!==after.get(file))changes.unmapped_modified.push(file);}
 report.incoming={ref:incoming,commit:sha,same_as_imported:sha===source.commit,changes,counts:Object.fromEntries(Object.entries(changes).map(([k,v])=>[k,v.length]))};
 report.warnings.push('Incoming lists compare source commits only. They are not an overwrite plan; local adapters, remapped paths and changed directory layouts still require review.');
}
if(snapshot){
 const stamp=report.created_utc.replace(/[-:]/g,'').replace(/\..*$/,'').replace('T','-');
 const destination=path.join(root,'.verification','story-handoff',stamp+'-'+report.head.slice(0,8));
 fs.mkdirSync(destination,{recursive:true});
 fs.writeFileSync(path.join(destination,'working-tree.patch'),git('diff','--binary','--',...scopes));
 fs.writeFileSync(path.join(destination,'index.patch'),git('diff','--cached','--binary','--',...scopes));
 for(const item of report.local_changes){if(item.deleted)continue;const dest=path.join(destination,'files',item.file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,item.file),dest);const hash=crypto.createHash('sha256').update(fs.readFileSync(dest)).digest('hex');if(hash!==item.sha256)throw Error('File changed while snapshotting: '+item.file);}
 report.snapshot=destination;
 fs.writeFileSync(path.join(destination,'handoff.json'),JSON.stringify(report,null,2)+'\n');
}
console.log(JSON.stringify({branch:report.branch,head:report.head,imported_source:report.source,incoming:report.incoming?{ref:report.incoming.ref,commit:report.incoming.commit,counts:report.incoming.counts}:null,shared_resources:report.shared_resources,maze03:report.maze03,local_files:report.local_changes.length,local_bytes:report.local_changes.reduce((n,f)=>n+(f.bytes||0),0),snapshot:report.snapshot||null,warnings:report.warnings},null,2));
