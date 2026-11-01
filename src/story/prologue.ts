import type { CharacterId } from '../characters/characters';

export interface DialogueLine {
  speaker: CharacterId;
  text: string;
}

// 原创占位文本，用于验证对话流程；正式剧本由叙事模块替换。
export const prologue: DialogueLine[] = [
  { speaker: 'narrator', text: '实验室的门还没有打开。桌上放着一本空白笔记，和一张等待探索的迷宫地图。' },
  { speaker: 'charlie', text: '他们让我记下每天发生的事。我想，从今天开始，我会认真地记住一切。' },
  { speaker: 'narrator', text: '走廊尽头传来轻轻的响动。阿尔吉侬已经在那里，等待下一次相遇。' },
];
