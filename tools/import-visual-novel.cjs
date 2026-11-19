const fs=require('fs'),cp=require('child_process'),path=require('path');
const ref='origin/feature/chapter1-interaction';
const dest='godot/modules/visual_novel/';
const sha=cp.execFileSync('git',['rev-parse',ref],{encoding:'utf8'}).trim();
const files=cp.execFileSync('git',['-c','core.quotepath=false','ls-tree','-r','--name-only',ref,'godot'],{encoding:'utf8'}).trim().split('\n');
const prefixes=['godot/assets/audio/','godot/assets/bakery/','godot/assets/continuation/','godot/assets/experience/','godot/assets/report/','godot/scripts/story/','godot/web/ink-observation/assets/'];
const exact=['godot/assets/fonts/YeLiHangJiuLinKaTong.ttf','godot/assets/fonts/REPORT-FONT-LICENSE.md','godot/scenes/story.tscn','godot/scenes/bakery.tscn','godot/scenes/report1.tscn','godot/ui/chapter1_theme.tres'];
const chosen=files.filter(f=>!f.endsWith('.import')&&!f.endsWith('.uid')&&(prefixes.some(p=>f.startsWith(p))||exact.includes(f)||(f.startsWith('godot/data/')&&f.endsWith('.json')&&!f.endsWith('/maze_01.json')))).filter(f=>f!=='godot/scripts/story/story_race.gd'&&!f.endsWith('/SourceHanSansSC-Regular.otf'));
const remaps=[['res://scripts/story/','res://modules/visual_novel/scripts/story/'],['res://scenes/story.tscn','res://modules/visual_novel/scenes/story.tscn'],['res://scenes/bakery.tscn','res://modules/visual_novel/scenes/bakery.tscn'],['res://scenes/report1.tscn','res://modules/visual_novel/scenes/report1.tscn'],['res://ui/chapter1_theme.tres','res://modules/visual_novel/ui/chapter1_theme.tres'],['res://data/','res://modules/visual_novel/data/'],['res://web/ink-observation/assets/','res://modules/visual_novel/web/ink-observation/assets/'],['res://assets/fonts/YeLiHangJiuLinKaTong.ttf','res://modules/visual_novel/assets/fonts/YeLiHangJiuLinKaTong.ttf']];
for(const name of ['audio','bakery','continuation','experience','report'])remaps.push(['res://assets/'+name+'/','res://modules/visual_novel/assets/'+name+'/']);
fs.mkdirSync(dest,{recursive:true});
const manifest=[];
for(const file of chosen){
 let data=cp.execFileSync('git',['show',sha+':'+file],{maxBuffer:50*1024*1024});
 const target=dest+file.slice(6);
 const textFile=/\.(gd|tscn|tres|json|gdshader|svg)$/.test(file);
 if(textFile){let text=data.toString('utf8');for(const [from,to] of remaps)text=text.split(from).join(to);data=Buffer.from(text);}
 fs.mkdirSync(path.dirname(target),{recursive:true});
 if(fs.existsSync(target))throw new Error('Refusing to overwrite existing file '+target);
 fs.writeFileSync(target,data);
 manifest.push({source:file,local:target.replace('godot/','res://'),paths_rebased:textFile});
}
fs.writeFileSync(dest+'source_manifest.json',JSON.stringify({repository:'jiangzhengzuo183-cmd/flowers',ref,commit:sha,files:manifest},null,2));
console.log('Imported '+chosen.length+' isolated story files from '+sha+'; original shared paths untouched.');
