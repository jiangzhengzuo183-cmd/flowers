import { chmod, copyFile, mkdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const root = new URL('../godot/', import.meta.url);
await mkdir(new URL('exports/web/media/', root), { recursive: true });
for (const file of ['story-video.js', 'media/charlie-dance.mp4']) {
  const source = new URL('web/' + file, root);
  const destination = new URL('exports/web/' + file, root);
  const existing = await readFile(destination).catch(error => {
    if (error.code === 'ENOENT') return null;
    throw error;
  });
  if (!existing || !existing.equals(await readFile(source))) {
    if (existing) await chmod(destination, 0o666);
    await copyFile(source, destination);
    await chmod(destination, 0o666);
  }
}
console.log('Story video packaged: ' + fileURLToPath(new URL('exports/web/media/charlie-dance.mp4', root)));
// Keep the approved ink module beside every Web export, including project subpaths.
await import('./package-ink-web.mjs');
