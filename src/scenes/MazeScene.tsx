import { useState } from 'react';
import { loadMaze01 } from '../maze/mazeData';
import { MazeViewport } from '../maze/MazeViewport';
import type { RouteId } from '../maze/types';

export default function MazeScene() {
  const [loaded] = useState(() => {
    try { return { data: loadMaze01(), error: '' }; }
    catch (cause) { return { data: null, error: cause instanceof Error ? cause.message : '地图读取失败' }; }
  });
  const [route, setRoute] = useState<RouteId>('none');
  const [resetToken, setResetToken] = useState(0);
  if (!loaded.data) return <div className="loading" role="alert">{loaded.error}</div>;
  const maze = loaded.data;
  return (
    <div className="maze-scene">
      <section className="maze-heading">
        <div><p className="eyebrow">THE LABYRINTH / 第一张地图</p><h1>每一次探索，<span>都从这里开始。</span></h1></div>
        <p>19 × 19 网格 · 灰盒预览<br /><span className="muted">拖动旋转 · 滚轮缩放 · 右键平移</span></p>
      </section>
      <div className="maze-toolbar">
        <div className="route-controls" role="group" aria-label="路线显示">
          {(['none', 'A', 'B'] as const).map(id => <button key={id} aria-pressed={route === id} onClick={() => setRoute(id)}>{id === 'none' ? '隐藏路线' : `路线 ${id} · ${maze.routes[id].moveCount} 步`}</button>)}
        </div>
        <button className="text-button" onClick={() => setResetToken(value => value + 1)}>重置视角 ↺</button>
      </div>
      <MazeViewport maze={maze} route={route} resetToken={resetToken} />
      <div className="maze-bottom"><div className="legend"><span><i className="entry-dot" />入口</span><span><i className="exit-dot" />出口</span><span><i className="checkpoint-dot" />检查点</span></div><p>地图已接入 · 人物移动与正式玩法将在后续加入</p></div>
    </div>
  );
}
