import { useEffect, useRef, useState } from 'react';
import { createMazeView } from './createMazeView';
import type { MazeData, RouteId } from './types';

export function MazeViewport({ maze, route, resetToken }: { maze: MazeData; route: RouteId; resetToken: number }) {
  const container = useRef<HTMLDivElement>(null);
  const view = useRef<ReturnType<typeof createMazeView> | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!container.current) return;
    try {
      view.current = createMazeView(container.current, maze);
      setError('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : '无法创建三维画面');
    }
    return () => { view.current?.dispose(); view.current = null; };
  }, [maze]);
  useEffect(() => { view.current?.setRoute(route); }, [route, maze]);
  useEffect(() => { view.current?.resetCamera(); }, [resetToken]);

  return <div className="maze-viewport" ref={container}>{error && <div className="canvas-error" role="alert"><h2>三维预览暂时无法显示</h2><p>请使用支持 WebGL 的浏览器，并开启硬件加速后重试。</p><small>{error}</small></div>}</div>;
}
