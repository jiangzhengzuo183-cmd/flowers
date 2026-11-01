import { lazy, Suspense, useState } from 'react';
import { StoryScene } from './scenes/StoryScene';

const MazeScene = lazy(() => import('./scenes/MazeScene'));
type SceneId = 'story' | 'maze';

export default function App() {
  const [scene, setScene] = useState<SceneId>('story');

  return (
    <div className="app-shell">
      <header className="site-header">
        <a className="wordmark" href="#" onClick={(event) => { event.preventDefault(); setScene('story'); }}>
          <span className="flower-mark" aria-hidden="true">✳</span>
          <span>献给阿尔吉侬的花束<small>FLOWERS FOR ALGERNON</small></span>
        </a>
        <nav aria-label="游戏场景">
          <button aria-current={scene === 'story' ? 'page' : undefined} onClick={() => setScene('story')}>01 / 故事</button>
          <button aria-current={scene === 'maze' ? 'page' : undefined} onClick={() => setScene('maze')}>02 / 迷宫</button>
        </nav>
        <span className="version-label">开发原型 · v0.1</span>
      </header>
      <main>
        {scene === 'story'
          ? <StoryScene onEnterMaze={() => setScene('maze')} />
          : <Suspense fallback={<div className="loading" role="status">正在准备迷宫……</div>}><MazeScene /></Suspense>}
      </main>
      <footer className="site-footer"><span>一段关于成长、记忆与陪伴的旅程</span><span>互动叙事 / 课程项目</span></footer>
    </div>
  );
}
