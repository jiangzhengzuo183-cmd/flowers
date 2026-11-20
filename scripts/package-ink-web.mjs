import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
const root=path.resolve(import.meta.dirname,'..'),out=path.join(root,'godot/exports/web');
if(!fs.existsSync(path.join(out,'index.html')))throw Error('Export the Godot Web preset first.');
fs.copyFileSync(path.join(root,'godot/web/ink-host.js'),path.join(out,'ink-host.js'));
fs.cpSync(path.join(root,'godot/web/ink-observation'),path.join(out,'ink-observation'),{recursive:true,filter:file=>!file.endsWith('.import')});
fs.writeFileSync(path.join(out,'.nojekyll'),'');
const digest=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
for(const name of ['app.js','flow.js','module.js','config.js','style.css','index.html']){
 const a=path.join(root,'godot/web/ink-observation',name),b=path.join(out,'ink-observation',name);if(digest(a)!==digest(b))throw Error('Module changed during copy: '+name);
}
console.log('Packaged original ink module and host adapter with relative paths: '+out);
