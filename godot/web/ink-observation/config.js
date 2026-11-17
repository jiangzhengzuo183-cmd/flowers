// 所有布局及运动参数集中于此。x/y 是 16:9 舞台内的中心点百分比。
window.INK_CONFIG = {
  cards: [
    { id: 'I',  x: 79, y: 65, angle: -7, src: 'assets/ink-I.png', background: 'transparent' },
    { id: 'IV', x: 39, y: 64, angle: -5, src: 'assets/ink-IV.png', background: 'transparent' },
    { id: 'V',  x: 65, y: 25, angle: 10, src: 'assets/ink-V.png', background: 'transparent' },
    { id: 'IX', x: 22, y: 26, angle: -9, src: 'assets/ink-IX.png', background: 'transparent' },
  ],
  layout: { cardWidth: 20, aspect: 1.15, focusWidth: 60, focusMaxHeight: 70, focusY: 50, hoverLift: 8 },
  animation: { duration: 400, reducedDuration: 100, easing: 'cubic-bezier(.22,.75,.25,1)' },
  // 观察时的滚轮缩放；最大倍率还会受舞台可用宽高限制。
  zoom: { min: 1, max: 1.35, sensitivity: .0016, duration: 180, padding: 16 },
  // 首轮增强：强度 .32 × 2.5、半径 .125 × 1.5、位移上限 .018 × 2.5。
  // recovery 越小复原越慢；3.8 约在 1—1.5 秒内基本复原。
  // inertia 为惯性释放时间（秒），speedInfluence 控制快速划过的拖曳增益。
  flow: { radius: .1875, strength: .80, maxDisplacement: .045, recovery: 3.8, inertia: .12, speedInfluence: .65, reducedStrength: .15 },
  // auto: 已有透明通道则原样使用；不透明扫描图按边缘纸色分离。
  // transparent: 明确按透明墨迹处理；paper: 明确分离纸色。
};
