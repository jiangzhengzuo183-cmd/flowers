import {createInkObservation} from './ink-observation/module.js';

// The vendor module is unchanged. All host state lives in this one adapter.
let active = null;
function position(entry) {
  const r=entry.canvas.getBoundingClientRect(),w=Math.min(r.width,r.height*16/9),h=w*9/16;
  Object.assign(entry.root.style,{left:`${r.left+(r.width-w)/2}px`,top:`${r.top+(r.height-h)/2}px`,width:`${w}px`,height:`${h}px`});
}
function dispose(entry) {
  if(active!==entry)return;
  active=null;entry.observer?.disconnect();entry.resize?.disconnect();entry.abort.abort();
  try{entry.module.destroy();}finally{
    entry.root.remove();entry.canvas.inert=entry.previousInert;entry.canvas.style.visibility=entry.previousVisibility;
    entry.canvas.focus({preventScroll:true});entry.callback=null;
  }
}
window.FlowerInk = {
  async open(callback) {
    if(active)throw new Error('Ink observation is already mounted');
    const canvas=document.getElementById('canvas');
    const root=document.createElement('section');root.setAttribute('aria-label','墨迹观察');
    root.style.cssText='position:fixed;z-index:1000;background:#302217;overflow:hidden;';
    const entry={canvas,root,callback,abort:new AbortController(),previousInert:canvas.inert,previousVisibility:canvas.style.visibility};
    entry.module=createInkObservation();active=entry;canvas.inert=true;canvas.style.visibility='hidden';
    document.body.append(root);position(entry);
    entry.resize=new ResizeObserver(()=>position(entry));entry.resize.observe(canvas);
    window.addEventListener('resize',()=>position(entry),{signal:entry.abort.signal});
    try{
      await entry.module.enter(root);if(active!==entry)return;
      const frame=root.querySelector('iframe'),doc=frame.contentDocument,inner=frame.contentWindow.inkObservation;
      // Hide only instructional decoration inside the isolated vendor document.
      const style=doc.createElement('style');style.textContent='#tell{display:none!important}.flower-finish{position:absolute;right:3%;bottom:3%;z-index:25;border:1px solid #a88750;border-radius:8px;background:#f5d487;color:#34464b;padding:10px 22px;font:inherit;box-shadow:0 2px 5px #21190c26;cursor:pointer}.flower-finish:focus-visible{outline:2px solid #fff3d6;outline-offset:3px}';doc.head.append(style);
      style.textContent += 'header,#desk-footer{display:none!important}.flower-tip{position:absolute;left:4%;bottom:3.2%;max-width:72%;margin:0;z-index:25;color:#fff3df;font-size:clamp(13px,1.1cqw,20px);line-height:1.5;letter-spacing:.02em;text-shadow:0 1px 3px #3e271e70;pointer-events:none}';
      const tip=doc.createElement('p');tip.className='flower-tip';doc.getElementById('stage').append(tip);
      const finish=doc.createElement('button');finish.type='button';finish.className='flower-finish';finish.textContent='结束观察';doc.getElementById('stage').append(finish);
      const update=()=>{const hidden=inner.phase!=='desk';if(finish.hidden!==hidden)finish.hidden=hidden;tip.textContent=hidden?'移动鼠标触碰墨迹，滚轮可缩放；按 Esc 或点击卡片外侧放回。':'点击卡片靠近观察；移动鼠标触碰墨迹；按 Esc 或点击空白处放回。';};
      entry.observer=new MutationObserver(update);entry.observer.observe(doc.getElementById('stage'),{attributes:true,subtree:true,attributeFilter:['class','hidden','inert','aria-modal']});update();
      finish.addEventListener('click',()=>{
        if(active!==entry||inner.phase!=='desk')return;
        const result=entry.module.complete({source:'chapter1-ink'}),done=entry.callback;
        dispose(entry);done?.(JSON.stringify({status:'completed',result}));
      },{signal:entry.abort.signal});
      frame.contentWindow.focus();
    }catch(error){
      if(active!==entry)return;
      const done=entry.callback;dispose(entry);done?.(JSON.stringify({status:'error',message:String(error.message||error)}));
    }
  },
  cancel(){const entry=active;if(entry)dispose(entry);},
  get mounted(){return active!==null;}
};
window.addEventListener('pagehide',()=>window.FlowerInk.cancel());
