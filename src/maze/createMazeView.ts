import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { createMazeWorld } from './createMazeWorld';
import type { MazeData, RouteId } from './types';

export function createMazeView(container: HTMLDivElement, maze: MazeData) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setClearColor('#e4e6e3');
  renderer.domElement.setAttribute('aria-label', '迷宫 01 三维预览，可拖动旋转和滚轮缩放');
  renderer.domElement.setAttribute('role', 'img');
  renderer.domElement.tabIndex = 0;
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const world = createMazeWorld(maze);
  scene.add(world.root);
  scene.add(new THREE.HemisphereLight('#ffffff', '#8f948a', 2.8));
  const sun = new THREE.DirectionalLight('#ffffff', 2.5);
  sun.position.set(-20, 70, 25);
  scene.add(sun);

  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 500);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.maxPolarAngle = Math.PI / 2 - 0.08;
  controls.minZoom = 0.5;
  controls.maxZoom = 5;
  const center = new THREE.Vector3(world.width / 2, 0, world.depth / 2);
  function resetCamera() {
    controls.target.copy(center);
    camera.position.copy(center).add(new THREE.Vector3(48, 72, 56));
    camera.zoom = 1;
    camera.updateProjectionMatrix();
    controls.update();
  }
  resetCamera();
  function resize() {
    const width = Math.max(container.clientWidth, 1);
    const height = Math.max(container.clientHeight, 1);
    const aspect = width / height;
    const halfHeight = Math.max(world.width, world.depth) * 0.8 * Math.max(1, 1 / aspect);
    camera.left = -halfHeight * aspect;
    camera.right = halfHeight * aspect;
    camera.top = halfHeight;
    camera.bottom = -halfHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height);
  }
  resize();
  const observer = new ResizeObserver(resize);
  observer.observe(container);
  renderer.setAnimationLoop(() => { controls.update(); renderer.render(scene, camera); });

  function onContextLost(event: Event) {
    event.preventDefault();
    renderer.setAnimationLoop(null);
  }
  function onContextRestored() {
    renderer.setAnimationLoop(() => { controls.update(); renderer.render(scene, camera); });
  }
  renderer.domElement.addEventListener('webglcontextlost', onContextLost);
  renderer.domElement.addEventListener('webglcontextrestored', onContextRestored);

  return {
    setRoute(id: RouteId) {
      world.routes.A.visible = id === 'A';
      world.routes.B.visible = id === 'B';
    },
    resetCamera,
    dispose() {
      observer.disconnect();
      renderer.setAnimationLoop(null);
      controls.dispose();
      renderer.domElement.removeEventListener('webglcontextlost', onContextLost);
      renderer.domElement.removeEventListener('webglcontextrestored', onContextRestored);
      const geometries = new Set<THREE.BufferGeometry>();
      const materials = new Set<THREE.Material>();
      scene.traverse(object => {
        if (object instanceof THREE.Mesh) {
          geometries.add(object.geometry);
          (Array.isArray(object.material) ? object.material : [object.material]).forEach(material => materials.add(material));
        }
      });
      geometries.forEach(geometry => geometry.dispose());
      materials.forEach(material => material.dispose());
      renderer.dispose();
      renderer.forceContextLoss();
      renderer.domElement.remove();
    },
  };
}
