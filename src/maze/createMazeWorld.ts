import * as THREE from 'three';
import type { Cell, MazeData } from './types';

export function createMazeWorld(maze: MazeData) {
  const root = new THREE.Group();
  const { rows, cols, cellSizeWorld: size, verticalWalls, horizontalWalls } = maze.grid;
  const width = cols * size;
  const depth = rows * size;
  const wallHeight = 3.2;
  const thickness = 0.3;
  const floor = new THREE.Mesh(new THREE.BoxGeometry(width + 1.4, 0.25, depth + 1.4), new THREE.MeshStandardMaterial({ color: '#eeede8', roughness: 1 }));
  floor.position.set(width / 2, -0.125, depth / 2);
  root.add(floor);

  const wallMaterial = new THREE.MeshStandardMaterial({ color: '#9b9d9b', roughness: 0.9 });
  const transform = new THREE.Object3D();
  // 每个矩阵边界只生成一次；墙段在转角处延长半个墙厚，避免接缝。
  function addWalls(matrix: boolean[][], vertical: boolean) {
    const count = matrix.flat().filter(Boolean).length;
    if (count === 0) return;
    const geometry = new THREE.BoxGeometry(vertical ? thickness : size + thickness, wallHeight, vertical ? size + thickness : thickness);
    const mesh = new THREE.InstancedMesh(geometry, wallMaterial, count);
    let index = 0;
    matrix.forEach((row, r) => row.forEach((wall, c) => {
      if (!wall) return;
      transform.position.set((c + (vertical ? 0 : 0.5)) * size, wallHeight / 2, (r + (vertical ? 0.5 : 0)) * size);
      transform.updateMatrix();
      mesh.setMatrixAt(index++, transform.matrix);
    }));
    mesh.instanceMatrix.needsUpdate = true;
    root.add(mesh);
  }
  addWalls(verticalWalls, true);
  addWalls(horizontalWalls, false);

  function marker(cell: Cell, color: string) {
    const mesh = new THREE.Mesh(new THREE.CylinderGeometry(size * 0.32, size * 0.32, 0.16, 24), new THREE.MeshBasicMaterial({ color }));
    mesh.position.set((cell[1] + 0.5) * size, 0.12, (cell[0] + 0.5) * size);
    root.add(mesh);
  }
  marker(maze.openings.entry.cell, '#e79346');
  marker(maze.openings.exit.cell, '#dc82a3');
  maze.checkpoints.forEach(point => marker(point.cell, '#459c98'));

  const routes = { A: new THREE.Group(), B: new THREE.Group() };
  for (const id of ['A', 'B'] as const) {
    const route = maze.routes[id];
    const material = new THREE.MeshBasicMaterial({ color: route.color });
    for (let i = 1; i < route.cellPath.length; i++) {
      const from = route.cellPath[i - 1];
      const to = route.cellPath[i];
      const segment = new THREE.Mesh(new THREE.BoxGeometry(from[1] === to[1] ? 0.15 : size + 0.15, 0.07, from[0] === to[0] ? 0.15 : size + 0.15), material);
      segment.position.set((from[1] + to[1] + 1) * size / 2, 0.24, (from[0] + to[0] + 1) * size / 2);
      routes[id].add(segment);
    }
    routes[id].visible = false;
    root.add(routes[id]);
  }
  return { root, routes, width, depth };
}
