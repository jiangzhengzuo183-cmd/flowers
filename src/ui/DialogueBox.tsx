import { characters } from '../characters/characters';
import type { DialogueLine } from '../story/prologue';

interface Props {
  line: DialogueLine;
  index: number;
  total: number;
  onNext: () => void;
  onRestart: () => void;
}

export function DialogueBox({ line, index, total, onNext, onRestart }: Props) {
  return (
    <section className="dialogue-box" aria-label="剧情对话">
      <div className="dialogue-heading"><span>{characters[line.speaker].name}</span><span className="muted">序章 · {index + 1} / {total}</span></div>
      <p aria-live="polite">{line.text}</p>
      <div className="dialogue-actions">
        <button className="text-button" onClick={onRestart}>重新阅读</button>
        <button className="primary-button" onClick={onNext}>{index < total - 1 ? '继续阅读' : '进入迷宫'} <span aria-hidden="true">↗</span></button>
      </div>
    </section>
  );
}
