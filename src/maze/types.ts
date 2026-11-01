export type Cell = [number, number];
export type Side = 'north' | 'east' | 'south' | 'west';
export type RouteId = 'none' | 'A' | 'B';

export interface MazeData {
  metadata: { name: string; version: string };
  grid: {
    rows: number;
    cols: number;
    cellSizeWorld: number;
    verticalWalls: boolean[][];
    horizontalWalls: boolean[][];
    cellWalls: Record<Side, boolean>[][];
  };
  openings: Record<'entry' | 'exit', { cell: Cell; side: Side }>;
  checkpoints: { id: string; cell: Cell }[];
  routes: Record<'A' | 'B', { color: string; cellPath: Cell[]; moveCount: number }>;
}
