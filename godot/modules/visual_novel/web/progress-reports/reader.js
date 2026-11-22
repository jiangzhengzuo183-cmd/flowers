/* StPageFlip 2.0.7 adapter. All artwork remains local; only soft single pages move. */
(() => {
 'use strict';
 const data=window.REPORT_DATA,$=s=>document.querySelector(s);
 const ordered=[...data.reports].sort((a,b)=>a.month-b.month||a.day-b.day);
 const hostConfig=window.REPORT_HOST_CONFIG||{};let introTurn=false;
 const media=matchMedia('(prefers-reduced-motion: reduce)');
 const model={ready:false,open:false,phase:'closed',unlocked:ordered.map(r=>r.id),visible:[],index:0,reduced:media.matches,motionOverride:false,turns:0};
 let flip=null,gesture=null,surfacePress=null,automaticTurn=false,preparing=false,queue=Promise.resolve(),resizePending=false,zoomFocus=null;
 const reader=$('#reader'),slot=$('#pages-slot'),select=$('#report-select'),dialog=$('#zoom-dialog');
 const pageFor=id=>data.pages.find(p=>p.id===id);
 const visibleReports=()=>ordered.filter(r=>model.unlocked.includes(r.id));
 const current=()=>model.visible[Math.floor(model.index/2)]||null;
 const binding=()=>model.phase==='opening'||model.phase==='closing';
 const busy=()=>binding()||!!gesture||!!flip&&flip.getState()!=='read';
 const emit=(name,detail)=>window.dispatchEvent(new CustomEvent('progress-report:'+name,{detail}));
 function state(){return {ready:model.ready,open:model.open,phase:model.phase,coverVisible:model.ready&&model.phase==='closed',reportId:current()?.id||null,date:current()?.date||null,pageIndex:model.index,spreadIndex:Math.floor(model.index/2),unlockedIds:[...model.unlocked],visibleIds:model.visible.map(r=>r.id),reducedMotion:model.reduced,zoomed:dialog.open,animating:busy(),flipState:flip?.getState()||'read',pageCount:model.visible.length*2,turns:model.turns,orientation:flip?.getOrientation()||'landscape'};}
 function sync(){
  if(!model.ready){$('#zoom-open').disabled=true;$('#report-close').disabled=true;return;}
  const report=current(),locked=busy()||!model.ready||!model.open||dialog.open;
  $('#prev').disabled=locked||model.index===0;$('#next').disabled=locked||model.index+2>=model.visible.length*2;
  $('#corner-prev').setAttribute('aria-disabled',String(locked||model.index===0));$('#corner-next').setAttribute('aria-disabled',String(locked||model.index+2>=model.visible.length*2));
  $('#corner-prev').tabIndex=model.index===0?-1:0;$('#corner-next').tabIndex=model.index+2>=model.visible.length*2?-1:0;
  select.disabled=locked||model.visible.length<2;if(report)select.value=report.id;
  $('#counter').textContent=model.visible.length?`${Math.floor(model.index/2)+1} / ${model.visible.length}`:'0 / 0';
  $('#reduced-motion').checked=model.reduced;$('#zoom-open').disabled=locked||!report;$('#report-continue').disabled=locked||!report;
  reader.hidden=!preparing&&(!model.ready||!model.open||model.phase!=='reading'||!model.visible.length);$('#reading-controls').hidden=reader.hidden||binding();
  $('#closed').hidden=!model.ready||model.phase==='reading';$('#reopen').disabled=!model.visible.length||binding();
  $('#report-close').disabled=!model.ready||!model.open||binding();$('#cover-summary').textContent=model.visible.length?`${model.visible.length} 组手账 · 书签停在${report?.date||'第一页'}`:'尚无已解锁的报告';$('#reopen').textContent=model.index>0?'继续阅读':'翻开笔记本';$('#cover-open').disabled=!model.visible.length||binding();$('#stage').classList.toggle('is-closed',model.phase==='closed');$('#stage').classList.toggle('is-binding',binding());
 }
 function canTurn(dir){return (hostConfig.mode!=='story'||introTurn)&&model.ready&&model.open&&!busy()&&!dialog.open&&(dir==='next'?model.index+2<model.visible.length*2:model.index>0);}
 function turn(dir){if(!canTurn(dir))return false;const target=model.index+(dir==='next'?2:-2);if(model.reduced){flip.turnToPage(target);sync();}else{automaticTurn=true;try{dir==='next'?flip.flipNext('bottom'):flip.flipPrev('bottom');}finally{automaticTurn=false;}sync();}return true;}
 function point(e){const r=slot.getBoundingClientRect();return {x:e.clientX-r.left,y:e.clientY-r.top};}
 // A stationary click anywhere on a page turns it. Body drags remain inert; corners retain folding.
 slot.addEventListener('pointerdown',e=>{if(e.button!==0||!model.open||busy()||dialog.open)return;const p=point(e),r=slot.getBoundingClientRect();if(Math.abs(p.x-r.width/2)<6)return;const dir=p.x<r.width/2?'prev':'next';if(!canTurn(dir))return;surfacePress={id:e.pointerId,start:p,dir,moved:false};slot.setPointerCapture(e.pointerId);});
 slot.addEventListener('pointermove',e=>{if(surfacePress?.id!==e.pointerId)return;const p=point(e);if(Math.hypot(p.x-surfacePress.start.x,p.y-surfacePress.start.y)>7)surfacePress.moved=true;});
 slot.addEventListener('pointerup',e=>{if(surfacePress?.id!==e.pointerId)return;const press=surfacePress;surfacePress=null;if(slot.hasPointerCapture(e.pointerId))slot.releasePointerCapture(e.pointerId);if(!press.moved)turn(press.dir);});
 slot.addEventListener('pointercancel',()=>{surfacePress=null;});slot.addEventListener('lostpointercapture',()=>{surfacePress=null;});
 // The library's native whole-page listeners are disabled. Only these two corner handles may start a gesture.
 function startCorner(e,dir){
  if(e.button!==undefined&&e.button!==0||!canTurn(dir))return;
  e.preventDefault();e.currentTarget.setPointerCapture(e.pointerId);gesture={pointerId:e.pointerId,target:e.currentTarget,dir,start:point(e),last:point(e),moved:false};sync();
 }
 function moveCorner(e){
  if(!gesture||gesture.pointerId!==e.pointerId)return;e.preventDefault();const p=point(e);gesture.last=p;
  if(model.reduced)return;
  if(!gesture.moved&&Math.hypot(p.x-gesture.start.x,p.y-gesture.start.y)>6){gesture.moved=true;flip.startUserTouch(gesture.start);flip.getFlipController().start(gesture.start);}
  if(gesture.moved)flip.userMove(p,true);
 }
 function endCorner(e,cancel=false){
  if(!gesture||e&&gesture.pointerId!==e.pointerId)return;const g=gesture;gesture=null;
  if(g.target.hasPointerCapture(g.pointerId))g.target.releasePointerCapture(g.pointerId);
  if(g.moved){if(cancel)flip.userMove(g.start,true);flip.userStop(cancel?g.start:g.last);}else if(!cancel)turn(g.dir);
  sync();
 }
 for(const [selector,dir] of [['#corner-prev','prev'],['#corner-next','next']]){
  const el=$(selector);el.addEventListener('pointerdown',e=>startCorner(e,dir));el.addEventListener('pointermove',moveCorner);
  el.addEventListener('pointerup',e=>endCorner(e));el.addEventListener('pointercancel',e=>endCorner(e,true));el.addEventListener('lostpointercapture',e=>{if(gesture)endCorner(e,true);});
  el.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();e.stopPropagation();turn(dir);}});
 }
 function closeZoom(){if(dialog.open)dialog.close();}
 function openZoom(){
  if(!model.open||busy()||!current())return;zoomFocus=document.activeElement;
  $('#zoom-title').textContent=current().date+' · 放大阅读';const container=$('#zoom-papers');container.replaceChildren();
  for(const id of current().pages){const box=document.createElement('div');box.innerHTML=pageFor(id).html;container.append(box);}
  dialog.showModal();$('#zoom-scale').value='1.2';sizeZoom();sync();$('#zoom-close').focus();
 }
 function sizeZoom(){const width=Math.max(860,dialog.clientWidth-42)*Number($('#zoom-scale').value);$('#zoom-papers').style.width=width+'px';}
 function onFlip(e){const previous=current()?.id;model.index=Math.floor(Number(e.data)/2)*2;if(previous&&previous!==current()?.id){model.turns++;emit('change',{reportId:current()?.id,date:current()?.date});}sync();}
 function onState(e){
  // 2.0.7 emits changeState before assigning its internal state. Refresh after that assignment.
  queueMicrotask(()=>{if(e.data==='read'&&resizePending){resizePending=false;flip.update();}sync();});
 }
 async function build(id){
  model.visible=visibleReports();select.replaceChildren(...model.visible.map(r=>new Option(r.date+(r.variantLabel?' · '+r.variantLabel:''),r.id)));
  const index=Math.max(0,model.visible.findIndex(r=>r.id===id))*2;model.index=index;
  if(!model.visible.length){if(flip){flip.clear();document.querySelectorAll('.report-page').forEach(p=>p.remove());}sync();return;}
  // Layout is measurable before PageFlip initializes; artwork stays invisible until both faces are ready.
  preparing=true;reader.hidden=false;slot.style.visibility='hidden';
  const elements=model.visible.flatMap(r=>r.pages).map(id=>{const p=pageFor(id),el=document.createElement('div');el.className='report-page';el.dataset.density='soft';el.dataset.pageId=p.id;el.dataset.reportId=p.reportId;el.innerHTML=p.html;return el;});
  if(!flip){
   flip=new St.PageFlip($('#book'),{width:data.design.pageWidth,height:data.design.pageHeight,size:'stretch',minWidth:60,maxWidth:1200,minHeight:60,maxHeight:1500,usePortrait:false,showCover:false,autoSize:false,drawShadow:true,maxShadowOpacity:.10,flippingTime:860,showPageCorners:false,useMouseEvents:false,disableFlipByClick:true,mobileScrollSupport:false,startPage:index});
   flip.on('flip',onFlip);flip.on('changeState',onState);flip.loadFromHTML(elements);
   // The pinned library advances a straight list of fold positions. Ease that progress gently,
   // preserving the same fold geometry and drag calculation; a release always gets time to settle.
   const renderer=flip.getRender(),startAnimation=renderer.startAnimation.bind(renderer);
   renderer.startAnimation=(frames,duration,done)=>{const n=frames.length;if(n<2)return startAnimation(frames,duration,done);const eased=Array.from({length:n},(_,i)=>{const t=i/(n-1),progress=t*t*(3-2*t);return frames[Math.round(progress*(n-1))];});return startAnimation(eased,automaticTurn?860:Math.max(280,duration),done);};
  }else{flip.updateFromHtml(elements);flip.turnToPage(index);}
  flip.update();await new Promise(requestAnimationFrame);preparing=false;slot.style.visibility='';sync();
 }
 function validateIds(ids){if(!Array.isArray(ids)||ids.some(id=>!ordered.some(r=>r.id===id)))throw new RangeError('包含报告清单中不存在的报告ID');return ordered.filter(r=>ids.includes(r.id)).map(r=>r.id);}
 async function rest(){if(gesture)endCorner(null,true);while(flip&&flip.getState()!=='read')await new Promise(requestAnimationFrame);}
 function serial(task){const result=queue.then(()=>ready).then(async()=>{await rest();return task();});queue=result.catch(()=>{});return result;}
 async function animateBinding(opening){
  const report=current();if(!report)return;
  model.phase=opening?'opening':'closing';surfacePress=null;sync();emit('binding',{phase:model.phase,reportId:report.id});
  try{await BookBinding.animate({opening,left:pageFor(report.pages[0]).html,right:pageFor(report.pages[1]).html,leftId:report.pages[0],rightId:report.pages[1],reduced:model.reduced});}
  finally{model.phase=opening?'reading':'closed';model.open=opening;sync();if(opening){flip.update();await new Promise(requestAnimationFrame);flip.update();}emit('binding',{phase:model.phase,reportId:report.id});}
 }
 async function openReport(id,options={}){return serial(async()=>{
  const ids=options.unlockedIds===undefined?model.unlocked:validateIds(options.unlockedIds);
  if(!ids.includes(id))throw new RangeError('报告尚未解锁或不在报告清单中');
  closeZoom();const wasOpen=model.open;model.open=true;const changed=JSON.stringify(ids)!==JSON.stringify(model.unlocked);model.unlocked=[...ids];
  if(options.reducedMotion!==undefined){model.motionOverride=true;model.reduced=!!options.reducedMotion;}
  reader.hidden=false;
  if(changed||!flip||!model.visible.length)await build(id);else{preparing=true;try{reader.hidden=false;model.index=model.visible.findIndex(r=>r.id===id)*2;flip.turnToPage(model.index);flip.update();}finally{preparing=false;}}
  if(!wasOpen&&options.animateCover!==false)await animateBinding(true);else{model.phase='reading';sync();flip.update();}emit('open',{reportId:id});return state();
 });}
 function turnToReport(id){return serial(async()=>{const target=model.visible.findIndex(r=>r.id===id)*2;if(target<0||!model.open)throw Error('目标报告尚未解锁');if(target===model.index)return state();if(Math.abs(target-model.index)!==2)throw Error('剧情入场必须从相邻跨页翻入');introTurn=true;try{if(!turn(target>model.index?'next':'prev'))throw Error('报告尚未准备好翻动');}finally{introTurn=false;}await rest();return state();});}
 async function closeBook(){if(!model.open)return state();surfacePress=null;closeZoom();await animateBinding(false);emit('close',{reportId:current()?.id||null});return state();}
 function closeReport(){return serial(closeBook);}
 function continueReport(){return serial(async()=>{if(!model.open)return state();const id=current()?.id;await closeBook();emit('continue',{reportId:id});return state();});}
 function setUnlockedReports(ids){const valid=validateIds(ids);return serial(async()=>{const id=current()?.id;closeZoom();if(!valid.length&&model.open)await closeBook();model.unlocked=valid;await build(valid.includes(id)?id:valid[0]);sync();return state();});}
 function setReducedMotion(value){if(value)BookBinding.finish();return serial(()=>{model.motionOverride=true;model.reduced=!!value;sync();return state();});}
 $('#prev').onclick=()=>turn('prev');$('#next').onclick=()=>turn('next');$('#report-close').onclick=()=>closeReport().catch(showStatus);
 $('#report-continue').onclick=()=>continueReport().catch(showStatus);
 select.onchange=()=>openReport(select.value).catch(showStatus);$('#reopen').onclick=()=>openReport(current()?.id||model.unlocked[0]).catch(showStatus);
 $('#cover-open').onclick=()=>openReport(current()?.id||model.unlocked[0]).catch(showStatus);
 $('#zoom-open').onclick=openZoom;$('#zoom-close').onclick=closeZoom;$('#zoom-scale').oninput=sizeZoom;
 dialog.addEventListener('close',()=>{sync();if(zoomFocus?.isConnected)zoomFocus.focus();});
 $('#reduced-motion').onchange=e=>setReducedMotion(e.target.checked).catch(showStatus);
 media.addEventListener('change',e=>{if(!model.motionOverride){if(e.matches)BookBinding.finish();serial(()=>{model.reduced=e.matches;sync();}).catch(showStatus);}});
 function showStatus(error){$('#status').textContent=error.message||String(error);}
 document.addEventListener('keydown',e=>{
  if(dialog.open)return;if(e.target.matches('select,input,textarea'))return;
  if(e.key==='ArrowRight'){e.preventDefault();turn('next');}else if(e.key==='ArrowLeft'){e.preventDefault();turn('prev');}else if(e.key==='Escape'&&model.open&&hostConfig.mode!=='story'){e.preventDefault();closeReport().catch(showStatus);}
 });
 window.addEventListener('blur',()=>{if(gesture)endCorner(null,true);});
 const resizeObserver=new ResizeObserver(()=>{if(!flip||!model.visible.length)return;if(busy())resizePending=true;else flip.update();if(dialog.open)sizeZoom();});resizeObserver.observe($('#assembly'));
 window.addEventListener('resize',()=>{if(BookBinding.active){BookBinding.finish();return;}if(!flip)return;if(gesture)endCorner(null,true);if(flip.getState()!=='read')flip.getRender().finishAnimation();flip.update();});
 const ready=(async()=>{
  if(!window.St?.PageFlip)throw Error('StPageFlip本地文件未加载，请保留vendor目录');
  await document.fonts.load('30px ReportHand');if(!document.fonts.check('30px ReportHand'))throw Error('报告字体加载失败');
  const urls=[data.base,data.paper,data.spine,data.cover,'assets/binding-front.png','assets/binding-stack.png',...data.pages.map(p=>p.art)];await Promise.all([...new Set(urls)].map(src=>new Promise((resolve,reject)=>{const im=new Image();im.onload=resolve;im.onerror=()=>reject(Error('图片加载失败：'+src));im.src=src;})));
  await build(ordered[0]?.id);model.ready=true;reader.setAttribute('aria-busy','false');$('#loading').hidden=true;sync();return state();
 })();
 ready.catch(error=>{$('#loading').classList.add('error');$('#loading').textContent=error.message;showStatus(error);});
 window.ProgressReports=Object.freeze({ready,openReport,turnToReport,closeReport,continueReport,setUnlockedReports,setReducedMotion,getState:state});
 // Compact test/host diagnostic; no setters or library objects are exposed to story code.
 window.reportPreview={get state(){return state();},manifest:data};
})();
