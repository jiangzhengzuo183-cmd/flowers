(() => {
  let dispose = null;
  window.closeFlowerStoryVideo = () => dispose?.();
  window.showFlowerStoryVideo = (source, title, volume, complete) => {
    dispose?.();
    const overlay = document.createElement('section');
    overlay.id = 'story-video';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', title);
    overlay.innerHTML = `<style>
      #story-video{position:fixed;inset:0;z-index:100;display:grid;place-items:center;background:#17201ee8;color:#fff6e8;font-family:'Microsoft YaHei',sans-serif}
      #story-video .film{position:relative;width:min(100vw,177.7778vh);aspect-ratio:16/9;background:#17201e;overflow:hidden}
      #story-video video{width:100%;height:100%;object-fit:contain;display:block}
      #story-video .film-title{position:absolute;top:5.9259%;left:3.3333%;margin:0;padding:8px 12px;border-radius:6px;background:#24352dbb;font-size:clamp(14px,1.25vw,24px);pointer-events:none}
      #story-video button{font:inherit;color:#384441;background:#f1cf7e;border:1px solid #c9b590;border-radius:8px;padding:10px 20px;cursor:pointer}
      #story-video button:focus-visible{outline:3px solid #fff6e8;outline-offset:3px}
      #story-video .skip{position:absolute;right:3.3333%;bottom:9%;font-size:clamp(14px,1.05vw,20px)}
      #story-video .play{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%)}
      #story-video .error{position:absolute;left:15%;right:15%;top:38%;text-align:center;background:#24352de6;border-radius:12px;padding:24px}
    </style><div class="film"><video playsinline controls preload="auto"></video><p class="film-title"></p><button class="play" hidden>播放视频</button><p class="error" hidden>视频暂时无法播放，可以重试或跳过。</p><button class="skip">跳过视频 · 继续剧情</button></div>`;
    const video = overlay.querySelector('video');
    const play = overlay.querySelector('.play');
    const skip = overlay.querySelector('.skip');
    const error = overlay.querySelector('.error');
    overlay.querySelector('.film-title').textContent = title;
    video.src = new URL(source, document.baseURI).href;
    video.volume = Math.min(1, Math.max(0, Number(volume)));
    let closed = false;
    const cleanup = () => {
      if (closed) return false;
      closed = true;
      video.pause();
      video.removeAttribute('src');
      video.load();
      document.removeEventListener('keydown', key, true);
      overlay.remove();
      dispose = null;
      document.querySelector('#canvas')?.focus();
      return true;
    };
    const finish = () => { if (cleanup()) complete(); };
    const key = event => {
      if (event.key === 'Escape') { event.preventDefault(); finish(); }
      if (event.key === 'Tab') {
        const focusable = [...overlay.querySelectorAll('video,button')].filter(el => !el.hidden);
        const index = focusable.indexOf(document.activeElement);
        const next = (index + (event.shiftKey ? -1 : 1) + focusable.length) % focusable.length;
        event.preventDefault(); focusable[next].focus();
      }
      event.stopImmediatePropagation();
    };
    play.onclick = () => { error.hidden = true; video.play().then(() => play.hidden = true).catch(() => play.hidden = false); };
    skip.onclick = finish;
    video.onended = finish;
    video.onerror = () => { error.hidden = false; play.hidden = false; play.textContent = '重试播放'; };
    document.body.append(overlay);
    document.addEventListener('keydown', key, true);
    dispose = cleanup;
    skip.focus();
    video.play().catch(() => { play.hidden = false; });
  };
})();
