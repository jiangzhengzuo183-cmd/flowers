import type { Cell, MazeData, Side } from './types.ts';

const sides: Side[] = ['north', 'east', 'south', 'west'];
const fail = (message: string): never => { throw new Error(`迷宫数据无效：${message}`); };

export function validateMaze(data: unknown): asserts data is MazeData {
  if (!data || typeof data !== 'object') fail('缺少地图对象');
  const maze = data as MazeData;
  const grid = maze.grid;
  if (!grid || !Number.isInteger(grid.rows) || !Number.isInteger(grid.cols) || grid.rows < 1 || grid.cols < 1) fail('行列数必须为正整数');
  const { rows, cols, verticalWalls: vertical, horizontalWalls: horizontal, cellWalls } = grid;
  if (!Number.isFinite(grid.cellSizeWorld) || grid.cellSizeWorld <= 0) fail('格子边长必须为正数');
  function matrix(value: unknown, height: number, width: number, name: string) {
    if (!Array.isArray(value) || value.length !== height || value.some(row => !Array.isArray(row) || row.length !== width || row.some(cell => typeof cell !== 'boolean'))) fail(`${name} 尺寸或墙体值不正确`);
  }
  matrix(vertical, rows, cols + 1, 'verticalWalls');
  matrix(horizontal, rows + 1, cols, 'horizontalWalls');
  function cellValid(cell: unknown): cell is Cell {
    return Array.isArray(cell) && cell.length === 2 && cell.every(Number.isInteger) && cell[0] >= 0 && cell[0] < rows && cell[1] >= 0 && cell[1] < cols;
  }
  if (!Array.isArray(cellWalls) || cellWalls.length !== rows) fail('缺少 cellWalls');
  for (let r = 0; r < rows; r++) {
    if (!Array.isArray(cellWalls[r]) || cellWalls[r].length !== cols) fail('cellWalls 尺寸不正确');
    for (let c = 0; c < cols; c++) {
      const expected = { north: horizontal[r][c], south: horizontal[r + 1][c], west: vertical[r][c], east: vertical[r][c + 1] };
      if (!cellWalls[r][c] || sides.some(side => cellWalls[r][c][side] !== expected[side])) fail(`cellWalls 与墙体矩阵不一致 [${r}, ${c}]`);
    }
  }
  for (const id of ['entry', 'exit'] as const) {
    const opening = maze.openings?.[id];
    if (!opening || !cellValid(opening.cell) || !sides.includes(opening.side)) fail(`${id} 开口格式不正确`);
    const [r, c] = opening.cell;
    const boundary = { north: r === 0, south: r === rows - 1, west: c === 0, east: c === cols - 1 };
    if (!boundary[opening.side] || cellWalls[r][c][opening.side]) fail(`${id} 开口被封闭或不在外边界`);
  }
  if (!Array.isArray(maze.checkpoints) || maze.checkpoints.some(point => typeof point.id !== 'string' || !cellValid(point.cell))) fail('检查点格式不正确');
  for (const id of ['A', 'B'] as const) {
    const route = maze.routes?.[id];
    if (!route || !Array.isArray(route.cellPath) || route.cellPath.length < 2 || route.cellPath.some(cell => !cellValid(cell))) fail(`路线 ${id} 坐标不正确`);
    const path = route.cellPath;
    if (route.moveCount !== path.length - 1) fail(`路线 ${id} 步数不一致`);
    if (path[0].toString() !== maze.openings.entry.cell.toString() || path.at(-1)!.toString() !== maze.openings.exit.cell.toString()) fail(`路线 ${id} 起终点不一致`);
    for (let i = 1; i < path.length; i++) {
      const [r, c] = path[i - 1];
      const dr = path[i][0] - r;
      const dc = path[i][1] - c;
      if (Math.abs(dr) + Math.abs(dc) !== 1) fail(`路线 ${id} 存在不相邻的格子`);
      const side = dr < 0 ? 'north' : dr > 0 ? 'south' : dc < 0 ? 'west' : 'east';
      if (cellWalls[r][c][side]) fail(`路线 ${id} 穿过墙体`);
    }
  }
  if (!maze.metadata || typeof maze.metadata.name !== 'string') fail('缺少地图名称');
}

export function countReachableCells(maze: MazeData): number {
  const queue: Cell[] = [maze.openings.entry.cell];
  const seen = new Set([queue[0].toString()]);
  const offsets: [Side, number, number][] = [['north', -1, 0], ['south', 1, 0], ['west', 0, -1], ['east', 0, 1]];
  for (let i = 0; i < queue.length; i++) {
    const [r, c] = queue[i];
    for (const [side, dr, dc] of offsets) {
      const next: Cell = [r + dr, c + dc];
      if (next[0] < 0 || next[0] >= maze.grid.rows || next[1] < 0 || next[1] >= maze.grid.cols || maze.grid.cellWalls[r][c][side] || seen.has(next.toString())) continue;
      seen.add(next.toString());
      queue.push(next);
    }
  }
  return seen.size;
}
