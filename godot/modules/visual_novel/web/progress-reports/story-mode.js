// This module is host-only: unlocked story events, not the current maximum date, select content.
(() => {
 const full=window.REPORT_DATA,catalog=window.REPORT_STORY_CATALOG;
 if(!window.REPORT_REQUIRES_HOST)return;
 const token=new URL(location.href).searchParams.get('session');let session=null;
 try{session=parent.FlowerReports?.getSession(token);}catch{}
 if(!session){window.REPORT_DATA={...full,reports:[],pages:[]};window.REPORT_HOST_CONFIG={mode:'review'};return;}
 const known=new Set(catalog.entries.map(e=>e.id));if(!Array.isArray(session.unlocked)||session.unlocked.some(id=>!known.has(id)))throw Error('剧情传入了不在清单中的报告');
 const unlocked=new Set(session.unlocked),reports=[],pages=[];
 for(const original of full.reports){const group=catalog.entries.filter(e=>e.spread===original.id),allowed=group.filter(e=>unlocked.has(e.id));if(!allowed.length)continue;
  const mask=group.reduce((mask,e,i)=>mask|(unlocked.has(e.id)?1<<i:0),0),variant=catalog.variants[original.id]?.[mask];if(!variant)throw Error('报告缺少当前解锁阶段的纸页');
  const date=[...new Set(allowed.map(e=>e.date))].join('／'),report={...original,date,variantLabel:'',sequence:reports.length,startPage:pages.length,pages:[],unlockedStageIds:allowed.map(e=>e.id)};
  for(const side of ['left','right']){const p=full.pages.find(p=>p.reportId===original.id&&p.side===side),all=allowed.some(e=>e.blocks[side]==='*'),ids=new Set(allowed.flatMap(e=>Array.isArray(e.blocks[side])?e.blocks[side]:[])),content=p.content.filter(b=>all||ids.has(b.id));
   const box=document.createElement('div');box.innerHTML=p.html;for(const text of box.querySelectorAll('[data-section]'))if(!all&&!ids.has(text.dataset.section))text.remove();box.querySelector('image').setAttribute('href',variant.art[side]);box.querySelector('svg').setAttribute('aria-label',date+(side==='left'?'左页':'右页'));
   const page={...p,index:pages.length,date,art:variant.art[side],content,html:box.innerHTML};pages.push(page);report.pages.push(page.id);
  }reports.push(report);
 }
 window.REPORT_DATA={...full,reports,pages};
 const target=catalog.entries.find(e=>e.id===session.currentReport),targetId=target?.spread;
 if(session.mode==='story'&&(!target||!unlocked.has(target.id)))throw Error('当前剧情报告尚未解锁');
 const index=reports.findIndex(r=>r.id===targetId);
 window.REPORT_HOST_CONFIG={mode:session.mode,reportId:targetId,previousId:index>0?reports[index-1].id:null,fromCover:!target||['report1','report2-0304'].includes(target.id)||index<=0};
 document.body.classList.add(session.mode==='story'?'is-story':'is-review');
})();
