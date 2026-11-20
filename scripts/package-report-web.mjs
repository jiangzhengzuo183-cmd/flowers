import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..'),source=path.join(root,'godot/web'),out=path.join(root,'godot/exports/web');
if(!fs.existsSync(path.join(source,'progress-reports/story-data.js')))throw Error('Run node scripts/build-report-book.cjs before exporting the story reader.');
fs.copyFileSync(path.join(source,'report-host.js'),path.join(out,'report-host.js'));
fs.cpSync(path.join(source,'progress-reports'),path.join(out,'progress-reports'),{recursive:true,filter:file=>!file.endsWith('.import')});
console.log('Packaged approved progress-report reader and story host with relative paths.');
