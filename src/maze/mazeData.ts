import rawMaze from './data/maze_01.json';
import { validateMaze } from './validateMaze';

export function loadMaze01() {
  validateMaze(rawMaze);
  return rawMaze;
}
