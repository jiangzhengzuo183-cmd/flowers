// A single same-origin session owns the iframe; the game remains paused until the cover is shut.
let active=null,sequence=0;
function position(entry){const r=entry.canvas.getBoundingClientRect(),w=Math.min(r.width,r.height*16/9),h=w*9/16;Object.assign(entry.root.style,{left:`${r.left+(r.width-w)/2}px`,top:`${r.top+(r.height-h)/2}px`,width:`${w}px`,height:`${h}px`});}
function dispose(entry){if(active!==entry)return;active=null;entry.abort.abort();entry.resize?.disconnect();entry.frame.remove();entry.root.remove();entry.canvas.inert=entry.previousInert;entry.canvas.style.visibility=entry.previousVisibility;entry.canvas.focus({preventScroll:true});entry.callback=null;}
function finish(entry,status,message=''){if(active!==entry)return;const done=entry.callback,reportId=entry.request.currentReport;dispose(entry);done?.(JSON.stringify({status,reportId,message}));}
window.FlowerReports=Object.freeze({
 async open(json,callback){if(active)throw Error('报告电子书已经打开');const request=JSON.parse(json);if(!['story','review'].includes(request.mode))throw Error('报告阅读模式无效');
  const canvas=document.getElementById('canvas'),root=document.createElement('section'),frame=document.createElement('iframe'),token='report-'+(++sequence)+'-'+Math.random().toString(36).slice(2);
  root.setAttribute('aria-label','查理的进步报告');root.style.cssText='position:fixed;z-index:1100;overflow:hidden;background:#b77b39;';frame.style.cssText='border:0;width:100%;height:100%;display:block;visibility:hidden;';frame.title='进步报告笔记本';
  const entry={canvas,root,frame,token,request,callback,abort:new AbortController(),previousInert:canvas.inert,previousVisibility:canvas.style.visibility,intro:true};active=entry;canvas.inert=true;canvas.style.visibility='hidden';root.append(frame);document.body.append(root);position(entry);entry.resize=new ResizeObserver(()=>position(entry));entry.resize.observe(canvas);window.addEventListener('resize',()=>position(entry),{signal:entry.abort.signal});
  const ready=new Promise((resolve,reject)=>{frame.onload=resolve;frame.onerror=()=>reject(Error('报告页面未能加载'));});frame.src=new URL(`./progress-reports/index.html?session=${token}`,import.meta.url).href;
  try{await ready;if(active!==entry)return;const win=frame.contentWindow,doc=frame.contentDocument,api=win.ProgressReports;if(!api)throw Error('报告阅读器未能初始化');await api.ready;if(active!==entry)return;
   const config=win.REPORT_HOST_CONFIG;doc.body.classList.add('is-entering');doc.addEventListener('keydown',event=>{if(entry.intro){event.preventDefault();event.stopImmediatePropagation();}else if(event.key==='Escape'&&request.mode==='review'&&api.getState().phase==='closed')finish(entry,'closed');},{capture:true,signal:entry.abort.signal});
   win.addEventListener('progress-report:continue',()=>{if(!entry.intro&&request.mode==='story')finish(entry,'completed');},{signal:entry.abort.signal});win.addEventListener('progress-report:close',()=>{if(!entry.intro&&request.mode==='review')finish(entry,'closed');},{signal:entry.abort.signal});
   if(request.mode==='review'){const back=document.createElement('button');back.textContent='返回剧情';back.type='button';back.style.cssText='position:absolute;right:4%;top:3%;z-index:20;padding:8px 18px;border:1px solid #b99a64;border-radius:5px;background:#f2ddb4;color:#4b3825;cursor:pointer;';root.append(back);win.addEventListener('progress-report:binding',()=>{back.hidden=api.getState().phase!=='closed';},{signal:entry.abort.signal});back.onclick=()=>{if(api.getState().phase==='closed')finish(entry,'closed');else if(!api.getState().animating)api.closeReport();};frame.style.visibility='';}
   else if(config.fromCover){frame.style.visibility='';await api.openReport(config.reportId);}
   else{await api.openReport(config.previousId,{animateCover:false});frame.style.visibility='';await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));await api.turnToReport(config.reportId);}
   if(active!==entry)return;entry.intro=false;doc.body.classList.remove('is-entering');win.focus();
  }catch(error){finish(entry,'error',String(error.message||error));}
 },
 getSession(token){return active&&active.token===token?structuredClone(active.request):null;},
 cancel(){if(active)dispose(active);},
 get mounted(){return !!active;},
 get state(){return active?{mode:active.request.mode,currentReport:active.request.currentReport,unlocked:[...active.request.unlocked],intro:active.intro,reader:active.frame.contentWindow?.ProgressReports?.getState()||null}:null;}
});
window.addEventListener('pagehide',()=>window.FlowerReports.cancel());
