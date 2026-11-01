export const characters = {
  charlie: { name: '查理', role: '故事的记录者' },
  narrator: { name: '旁白', role: '场景叙述' },
} as const;

export type CharacterId = keyof typeof characters;
