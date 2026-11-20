(() => {
  'use strict';
  let disposed=false,completed=false;
  const lifecycle=new AbortController();
  function listen(target,type,callback,options={}) {
    target.addEventListener(type,callback,typeof options==='boolean'?{capture:options,signal:lifecycle.signal}:{...options,signal:lifecycle.signal});
  }
  const config=window.INK_CONFIG;
  const  stage=document.querySelector('#stage'),cardsRoot=document.querySelector('#cards');
  const footer=document.querySelector('#desk-footer'),tell=document.querySelector('#tell'),response=document.querySelector('#response');
  const announce=document.querySelector('#announcement');
  const reduce=matchMedia('(prefers-reduced-motion: reduce)');
  const cards=[];let phase='desk',selected=null,timer=0,returned=0,pointerOrigin=null;
  let zoom=1,maxZoom=1;
  function duration(){return reduce.matches?config.animation.reducedDuration:config.animation.duration;}
  function layout(){
    const l=config.layout,r=stage.getBoundingClientRect();
    stage.style.setProperty('--card-width',l.cardWidth+'%');stage.style.setProperty('--aspect',l.aspect);
    const baseWidth=Math.min(r.width*l.focusWidth/100,r.height*l.focusMaxHeight/100*l.aspect);
    const padding=Math.min(config.zoom.padding,r.width*.03,r.height*.03);
    const availableWidth=Math.max(1,r.width-2*padding);
    const availableHeight=Math.max(1,2*Math.min(l.focusY/100,1-l.focusY/100)*r.height-2*padding);
    const fitWidth=Math.min(availableWidth,availableHeight*l.aspect);
    maxZoom=Math.max(config.zoom.min,Math.min(config.zoom.max,fitWidth/baseWidth));
    stage.style.setProperty('--focus-width',baseWidth/r.width*100+'%');
    // max-width is not animated: resizing the window can never leave the paper
    // temporarily outside the stage while the smooth width transition catches up.
    stage.style.setProperty('--zoom-fit-width',fitWidth+'px');
    stage.style.setProperty('--zoom-duration',(reduce.matches?config.animation.reducedDuration:config.zoom.duration)+'ms');
    stage.style.setProperty('--focus-y',l.focusY+'%');stage.style.setProperty('--hover-lift',reduce.matches?'2px':l.hoverLift+'px');
    stage.style.setProperty('--duration',duration()+'ms');stage.style.setProperty('--ease',config.animation.easing);
    if(selected){zoom=Math.min(zoom,maxZoom);selected.el.style.setProperty('--zoom',zoom);}
  }
  const resizeObserver=new ResizeObserver(layout);resizeObserver.observe(stage);listen(reduce,'change',layout);layout();
  function stopTimer(){clearTimeout(timer);}
  function open(item){
    if(disposed||phase!=='desk')return;
    stopTimer();phase='opening';selected=item;zoom=config.zoom.min;
    item.el.classList.remove('zooming');item.el.style.setProperty('--zoom',zoom);
    // Same DOM node throughout: no cloned cards or animation coordinates to go stale.
    for(const c of cards){c.el.inert=c!==item; c.el.tabIndex=c===item?0:-1;}
    footer.hidden=true;stage.classList.add('observing');
    stage.setAttribute('role','dialog');stage.setAttribute('aria-modal','true');
    stage.setAttribute('aria-label',`观察图版 ${item.id}`);item.el.classList.add('selected');
    item.el.setAttribute('aria-expanded','true');item.el.focus({preventScroll:true});
    announce.textContent=`已拿起图版 ${item.id}${item.loaded?'':'，标准墨迹素材待补充'}`;
    timer=setTimeout(()=>{if(phase!=='opening')return;phase='observing';if(item.flow?.ready){item.flow.start();item.el.classList.add('flow-ready');}},duration()+30);
  }
  function close(){
    if(disposed||(phase!=='opening'&&phase!=='observing'))return;
    stopTimer();phase='closing';const item=selected;
    item.flow?.stop();item.el.classList.add('returning');item.el.classList.remove('flow-ready','selected','zooming');item.el.setAttribute('aria-expanded','false');
    stage.classList.add('returning');
    timer=setTimeout(()=>{
      if(phase!=='closing')return;
      item.viewed=true;item.el.classList.remove('returning');item.el.classList.add('viewed');zoom=config.zoom.min;item.el.style.setProperty('--zoom',zoom);returned++;selected=null;phase='desk';
      stage.classList.remove('observing','returning');
      for(const c of cards){c.el.inert=false;c.el.tabIndex=0;}
      stage.removeAttribute('role');stage.removeAttribute('aria-modal');stage.setAttribute('aria-label','墨迹卡片观察桌面');
      footer.hidden=false;tell.hidden=returned===0;item.el.focus({preventScroll:true});announce.textContent=`图版 ${item.id} 已放回桌面`;
    },duration()+30);
  }
  function showResponse(){
    if(phase!=='desk'||!returned)return;
    phase='response';response.hidden=false;cardsRoot.inert=true;footer.inert=true;
    response.setAttribute('role','dialog');response.setAttribute('aria-modal','true');document.querySelector('#continue').focus();
  }
  function continueLooking(reset=false){
    if(phase!=='response')return;
    response.hidden=true;cardsRoot.inert=false;footer.inert=false;phase='desk';
    if(reset){returned=0;for(const c of cards){c.viewed=false;c.el.classList.remove('viewed');}tell.hidden=true;}
    cards[0].el.focus({preventScroll:true});
  }
  // Capture outside gestures across the whole viewport, including letterbox margins.
  // Remember where a press began: a drag that begins on the ink never dismisses it.
  // Consume the closing click before the underlying card can see it, even if an
  // unusually long press finishes after the return animation has completed.
  listen(document,'pointerdown',e=>{
    pointerOrigin=null;
    if(!selected||!['opening','observing','closing'].includes(phase))return;
    pointerOrigin=selected.el.contains(e.target)?'inside':'outside';
    if(pointerOrigin==='outside'){e.preventDefault();e.stopImmediatePropagation();}
  },true);
  listen(document,'pointercancel',()=>{pointerOrigin=null;},true);
  listen(document,'click',e=>{
    const origin=pointerOrigin;pointerOrigin=null;
    const outside=selected&&!selected.el.contains(e.target)&&['opening','observing','closing'].includes(phase);
    if(origin==='outside'||outside){
      e.preventDefault();e.stopImmediatePropagation();
      if(origin!=='inside'&&outside&&(phase==='opening'||phase==='observing'))close();
    }
  },true);
  listen(tell,'click',showResponse);
  listen(document.querySelector('#continue'),'click',()=>continueLooking());
  listen(document.querySelector('#restart'),'click',()=>continueLooking(true));
  listen(document,'keydown',e=>{
    if(e.key==='Escape'){e.preventDefault();if(phase==='response')continueLooking();else close();}
    if(e.key==='Tab'&&selected&&['opening','observing','closing'].includes(phase)){e.preventDefault();selected.el.focus({preventScroll:true});}
    if(e.key==='Tab'&&phase==='response'){
      e.preventDefault();const a=document.querySelector('#continue'),b=document.querySelector('#restart');(document.activeElement===a?b:a).focus();
    }
  });
  listen(window,'blur',()=>selected?.flow?.leave());
  listen(document,'visibilitychange',()=>{if(document.hidden)selected?.flow?.leave();});

  async function prepareInk(src,mode){
    const image=new Image();image.src=src;await image.decode();
    const input=document.createElement('canvas'),scale=Math.min(1,2048/Math.max(image.width,image.height));
    input.width=Math.round(image.width*scale);input.height=Math.round(image.height*scale);
    const ctx=input.getContext('2d',{willReadFrequently:true});ctx.drawImage(image,0,0,input.width,input.height);
    const pixels=ctx.getImageData(0,0,input.width,input.height),d=pixels.data,w=input.width,h=input.height;
    const corners=[[0,0],[w-1,0],[0,h-1],[w-1,h-1]];const transparent=corners.some(([x,y])=>d[(y*w+x)*4+3]<16);
    if(mode==='paper'||(mode==='auto'&&!transparent)){
      // Estimate the stationary paper from edge pixels; reconstruct premultiplied ink
      // rather than moving the source's rectangular paper scan as a texture.
      const channels=[[],[],[]];
      for(let x=0;x<w;x+=Math.max(1,Math.floor(w/100)))for(const y of[0,h-1])for(let c=0;c<3;c++)channels[c].push(d[(y*w+x)*4+c]);
      for(let y=0;y<h;y+=Math.max(1,Math.floor(h/100)))for(const x of[0,w-1])for(let c=0;c<3;c++)channels[c].push(d[(y*w+x)*4+c]);
      const paper=channels.map(a=>a.sort((a,b)=>a-b)[Math.floor(a.length*.6)]||255);
      for(let i=0;i<d.length;i+=4){
        let a=1-Math.min(d[i]/paper[0],d[i+1]/paper[1],d[i+2]/paper[2],1);
        if(a<.025){d[i+3]=0;continue;}
        for(let c=0;c<3;c++)d[i+c]=Math.max(0,Math.min(255,(d[i+c]-(1-a)*paper[c])/a));
        d[i+3]=Math.round(a*255);
      }
      ctx.putImageData(pixels,0,0);
    }
    const layer=document.createElement('canvas');layer.width=1200;layer.height=Math.round(1200/config.layout.aspect);
    const fit=Math.min(layer.width*.82/input.width,layer.height*.82/input.height),dw=input.width*fit,dh=input.height*fit;
    layer.getContext('2d').drawImage(input,(layer.width-dw)/2,(layer.height-dh)/2,dw,dh);
    const result=new Image();result.src=layer.toDataURL();await result.decode();return result;
  }
  for(const c of config.cards){
    const el=document.createElement('button');el.className='card';el.type='button';el.dataset.id=c.id;
    el.style.setProperty('--x',c.x+'%');el.style.setProperty('--y',c.y+'%');el.style.setProperty('--angle',c.angle+'deg');
    el.setAttribute('aria-label',`拿起查看图版 ${c.id}，素材待补充`);el.setAttribute('aria-expanded','false');
    el.innerHTML=`<span class="plate-id">${c.id}</span><span class="missing"><strong>${c.id}</strong><span>标准墨迹素材待补充</span></span><span class="pickup">拿起查看</span><span class="viewed-dot" aria-hidden="true"></span>`;
    cardsRoot.append(el);const item={...c,el,loaded:false,viewed:false,flow:null};cards.push(item);
    listen(el,'click',e=>{e.stopPropagation();open(item);});
    listen(el,'pointermove',e=>{if(phase!=='observing'||selected!==item)return;item.flow?.moveClient(e.clientX,e.clientY,e.timeStamp);});
    listen(el,'pointerleave',()=>item.flow?.leave());
    listen(el,'wheel',e=>{
      if(phase!=='observing'||selected!==item)return;
      const r=el.getBoundingClientRect();
      if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)return;
      e.preventDefault();e.stopPropagation();
      const unit=e.deltaMode===1?16:e.deltaMode===2?r.height:1;
      const delta=Math.max(-240,Math.min(240,e.deltaY*unit));
      if(!delta)return;
      zoom=Math.max(config.zoom.min,Math.min(maxZoom,zoom*Math.exp(-delta*config.zoom.sensitivity)));
      el.classList.add('zooming');el.style.setProperty('--zoom',zoom);
    },{passive:false});
  }
  async function loadAssets(){
    // Load relative assets directly; works on any static host, including Pages.
    await Promise.all(cards.map(async item=>{
      if(disposed)return;
      try{
        const image=await prepareInk(item.src,item.background);if(disposed)return;image.className='ink-image';image.alt=`墨迹图版 ${item.id}`;
        item.el.querySelector('.missing').remove();item.el.append(image);item.loaded=true;item.el.setAttribute('aria-label',`拿起查看图版 ${item.id}`);
        const canvas=document.createElement('canvas');canvas.setAttribute('aria-hidden','true');item.el.append(canvas);
        item.flow=new InkFlow(canvas,image,{...config.flow,aspect:config.layout.aspect});
        if(selected===item&&phase==='observing'&&item.flow.ready){item.flow.start();item.el.classList.add('flow-ready');}
      }catch{
        const message=item.el.querySelector('.missing span');
        if(message)message.textContent='图片无法读取，请检查素材';
        // Failure to initialize a GPU layer must not hide a successfully loaded image.
        item.el.classList.remove('flow-ready');
      }
    }));
    if(!disposed)stage.dataset.assetsReady='true';
  }
  const ready=loadAssets();
  function result(data={}) {return {viewed:cards.filter(c=>c.viewed).map(c=>c.id),missing:cards.filter(c=>!c.loaded).map(c=>c.id),data};}
  function complete(data={}) {
    if(disposed)throw new Error('Module has exited');
    if(completed)return null;
    completed=true;return result(data);
  }
  function destroy() {
    if(disposed)return;
    disposed=true;stopTimer();lifecycle.abort();resizeObserver.disconnect();
    for(const c of cards){c.flow?.destroy();c.el.remove();}
    selected=null;phase='exited';
  }
  window.inkObservation={ready,complete,destroy,get disposed(){return disposed;},get phase(){return phase;},get selected(){return selected?.id||null;},get zoom(){return zoom;},get maxZoom(){return maxZoom;},get missing(){return cards.filter(c=>!c.loaded).map(c=>c.id);},get flowEnergy(){return selected?.flow?.energy||0;},get flowMaxDisplacement(){return selected?.flow?.maxDisplacement||0;},get flowReady(){return selected?.flow?.ready||false;},config};
})();
