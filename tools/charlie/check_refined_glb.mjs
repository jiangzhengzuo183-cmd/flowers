import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

function read(filename) {
  const bytes = readFileSync(new URL(`../../godot/assets/characters/charlie/${filename}`, import.meta.url));
  assert.equal(bytes.toString('ascii', 0, 4), 'glTF');
  assert.equal(bytes.readUInt32LE(8), bytes.length);
  let json, binary;
  for (let offset = 12; offset < bytes.length;) {
    const length = bytes.readUInt32LE(offset);
    const type = bytes.readUInt32LE(offset + 4);
    if (type === 0x4e4f534a) json = JSON.parse(bytes.subarray(offset + 8, offset + 8 + length));
    if (type === 0x004e4942) binary = bytes.subarray(offset + 8, offset + 8 + length);
    offset += 8 + length;
  }
  return { json, binary };
}

function view(model, index) {
  const item = model.json.bufferViews[index];
  return model.binary.subarray(item.byteOffset || 0, (item.byteOffset || 0) + item.byteLength);
}

function accessor(model, index) {
  const item = model.json.accessors[index];
  const data = view(model, item.bufferView);
  const components = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 }[item.type];
  const bytes = { 5121: 1, 5123: 2, 5125: 4, 5126: 4 }[item.componentType];
  const stride = model.json.bufferViews[item.bufferView].byteStride || components * bytes;
  return Buffer.concat(Array.from({ length: item.count }, (_, i) => {
    const start = (item.byteOffset || 0) + i * stride;
    return data.subarray(start, start + components * bytes);
  }));
}

const original = read('charlie.glb');
const refined = read('charlie_refined.glb');
const before = original.json.meshes[0].primitives[0];
const after = refined.json.meshes[0].primitives[0];
for (const [name, index] of Object.entries(before.attributes)) {
  assert.ok(accessor(original, index).equals(accessor(refined, after.attributes[name])), `Changed mesh attribute ${name}`);
}
assert.ok(accessor(original, before.indices).equals(accessor(refined, after.indices)), 'Changed triangles');
assert.deepEqual(original.json.materials, refined.json.materials, 'Changed materials');
assert.ok(view(original, original.json.images[0].bufferView).equals(view(refined, refined.json.images[0].bufferView)), 'Changed texture');
const armNames = new Set(['Left', 'Right'].flatMap(side => ['UpperArm', 'LowerArm', 'Hand'].map(part => side + part)));
let changedRotations = 0;
for (const animation of original.json.animations) {
  const revision = refined.json.animations.find(item => item.name === animation.name);
  assert.ok(revision, `Missing clip ${animation.name}`);
  for (const channel of animation.channels) {
    const name = original.json.nodes[channel.target.node].name;
    const target = revision.channels.find(item => refined.json.nodes[item.target.node].name === name && item.target.path === channel.target.path);
    assert.ok(target, `Missing track ${name}`);
    const samplerA = animation.samplers[channel.sampler], samplerB = revision.samplers[target.sampler];
    assert.ok(accessor(original, samplerA.input).equals(accessor(refined, samplerB.input)), 'Changed key times');
    const a = accessor(original, samplerA.output), b = accessor(refined, samplerB.output);
    assert.equal(a.length, b.length, 'Changed sample count');
    if (animation.name === 'Run-loop' && armNames.has(name) && channel.target.path === 'rotation') {
      if (!a.equals(b)) changedRotations++;
    } else {
      // Exporter matrix decomposition can add sub-micrometre float noise to
      // child-arm positions/scales when their parent rotation changes.
      let error = 0;
      for (let i = 0; i < a.length; i += 4) error = Math.max(error, Math.abs(a.readFloatLE(i) - b.readFloatLE(i)));
      assert.ok(error < 0.000002, `Changed non-arm motion ${animation.name}/${name}/${channel.target.path}: ${error}`);
    }
  }
}
assert.equal(changedRotations, 6, 'Expected exactly six revised arm rotations');
console.log('REFINED GLB CHECK: PASS | geometry, UV, normals, weights, triangles, texture and other motion preserved; six Run arm rotations revised');
