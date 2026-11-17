/** Mount the confirmed HTML prototype without leaking its CSS or events to the host. */
export function createInkObservation({onEnter,onExit,onComplete}={}) {
  let active=null,disposed=false;
  const abortError=()=>new DOMException('Observation entry was cancelled','AbortError');
  const api={
    enter(container){
      if(disposed)return Promise.reject(new Error('This module instance has been destroyed'));
      if(!(container instanceof HTMLElement))return Promise.reject(new TypeError('enter() requires an HTMLElement'));
      if(active){
        if(active.container!==container)return Promise.reject(new Error('Exit before mounting into another container'));
        return active.promise;
      }
      const frame=document.createElement('iframe'),controller=new AbortController();
      frame.title='墨迹卡片观察';frame.setAttribute('allow','');
      frame.style.cssText='display:block;width:100%;height:100%;border:0;';
      const entry={frame,container,controller,inner:null,completed:false};active=entry;
      entry.promise=new Promise((resolve,reject)=>{
        const timeout=setTimeout(()=>{reject(new Error('Module did not load within 30 seconds'));if(active===entry)api.exit();},30000);
        const finish=()=>clearTimeout(timeout);
        controller.signal.addEventListener('abort',()=>{finish();reject(abortError());},{once:true});
        frame.addEventListener('load',async()=>{
          try{
            if(active!==entry)throw abortError();
            const inner=frame.contentWindow.inkObservation;
            if(!inner)throw new Error('Observation module failed to initialize');
            entry.inner=inner;await inner.ready;
            if(active!==entry)throw abortError();
            if(inner.missing.length)throw new Error('Missing ink assets: '+inner.missing.join(', '));
            finish();onEnter?.();resolve(api);
          }catch(error){finish();reject(error);if(active===entry)api.exit();}
        },{once:true,signal:controller.signal});
      });
      // URL is relative to this ES module, so repository subpaths work unchanged.
      frame.src=new URL('./index.html',import.meta.url).href;
      container.append(frame);return entry.promise;
    },
    exit(){
      const entry=active;if(!entry)return;
      active=null;entry.controller.abort();
      try{(entry.inner||entry.frame.contentWindow?.inkObservation)?.destroy();}
      finally{entry.frame.remove();onExit?.();}
    },
    complete(data={}){
      if(!active?.inner)throw new Error('Call and await enter() before complete()');
      if(active.completed)return null;
      active.completed=true;
      const result=active.inner.complete(data);
      onComplete?.(result);return result;
    },
    destroy(){if(disposed)return;disposed=true;api.exit();},
    get mounted(){return active!==null;},
  };
  return api;
}
