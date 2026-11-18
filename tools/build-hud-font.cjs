const fs=require('fs'),path=require('path'),crypto=require('crypto');
const repo=path.resolve(__dirname,'..');
const {createFont}=require(path.join(repo,'.tools/hud-font-tools/node_modules/fonteditor-core'));
const source=path.join(repo,'.tools/hud-font-source/xiaolai.ttf');
const roots=['modules/game_hud','modules/maze_items','modules/maze_keys','modules/maze_pickups','modules/maze02_items','modules/maze03_race','modules/maze03_sanctuary'];
let text=Array.from({length:95},(_,i)=>String.fromCodePoint(i+32)).join('');
for(const root of roots){const folder=path.join(repo,'godot',root);for(const file of fs.readdirSync(folder,{recursive:true})){if(/\.(gd|tres)$/.test(file))text+=fs.readFileSync(path.join(folder,file),'utf8');}}
for(const file of ['greybox_scene.gd','maze01_key_scene.gd','maze02_scene.gd'])text+=fs.readFileSync(path.join(repo,'godot/scripts/levels',file),'utf8');
const codes=[...new Set([...text].map(s=>s.codePointAt(0)))].filter(x=>x>=32).sort((a,b)=>a-b);
const font=createFont(fs.readFileSync(source),{type:'ttf',subset:codes,hinting:true,kerning:false,compound2simple:true});
const data=font.get();
data.name.licence=fs.readFileSync(path.join(repo,'.tools/hud-font-source/xiaolai-OFL.txt'),'utf8');
data.name.fontFamily='Algernon HUD Hand';data.name.fontSubFamily='Regular';data.name.fullName='Algernon HUD Hand Regular';data.name.postScriptName='AlgernonHUDHand-Regular';data.name.uniqueSubFamily='Algernon HUD Hand:1.0';data.name.version='Version 1.0; HUD subset from original v3.126';
const bytes=font.write({type:'ttf',hinting:true,kerning:false});
const out=path.join(repo,'godot/assets/UI/HUD/fonts');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'HUDHand.ttf'),Buffer.from(bytes));fs.copyFileSync(path.join(repo,'.tools/hud-font-source/xiaolai-OFL.txt'),path.join(out,'OFL.txt'));
fs.writeFileSync(path.join(out,'SOURCE.md'),'# HUD handwritten typeface\n\nDerived subset of Xiaolai Regular v3.126, renamed Algernon HUD Hand. Source: https://github.com/lxgw/kose-font/releases/tag/v3.126 . SIL OFL 1.1; full original license and copyright are in OFL.txt. Glyph outlines unchanged; only included characters and font family names are changed. Existing Source Han Sans remains the fallback for future text.\n\nBuild: node tools/build-hud-font.cjs, using fonteditor-core in the ignored .tools folder. No runtime dependency is added.\n');
fs.writeFileSync(path.join(out,'subset.json'),JSON.stringify({source_version:'v3.126',source_sha256:crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),glyphs:data.glyf.length,bytes:bytes.length,codepoints:codes},null,2));
console.log(JSON.stringify({glyphs:data.glyf.length,bytes:bytes.length}));
