import { useState } from 'react';
import { prologue } from '../story/prologue';
import { DialogueBox } from '../ui/DialogueBox';

export function StoryScene({ onEnterMaze }: { onEnterMaze: () => void }) {
  const [index, setIndex] = useState(0);
  return (
    <div className="story-scene">
      <section className="story-intro">
        <p className="eyebrow">PROLOGUE / 序章</p>
        <h1>每一条路，<br />都通向一次<span>相遇。</span></h1>
        <p className="intro-copy">翻开笔记，走进迷宫。<br />在故事与探索之间，留下属于你的进步报告。</p>
        <div className="chapter-note"><span>01</span><div>实验开始之前<small>一页空白的笔记，一段未写完的故事。</small></div></div>
      </section>
      <section className="story-right">
        <div className="notebook-art" aria-hidden="true">
          <div className="notebook-spine" /><div className="notebook-label">PROGRESS<br />REPORT<span>进步报告</span><small>CHARLIE GORDON</small></div>
          <div className="paper-flower">✳</div><span className="art-caption">从一页空白开始 / 001</span>
        </div>
        <DialogueBox line={prologue[index]} index={index} total={prologue.length} onRestart={() => setIndex(0)} onNext={() => index < prologue.length - 1 ? setIndex(index + 1) : onEnterMaze()} />
      </section>
    </div>
  );
}
