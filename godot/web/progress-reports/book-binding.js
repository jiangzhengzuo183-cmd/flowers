/* Physical cover/bound-page-group animation, separate from soft inner-page turns. */
(() => {
 'use strict';
 const $=s=>document.querySelector(s),quad=[[46,68],[415,18],[519,539],[131,603]];
 const face=[[534,14],[1061,14],[1061,650],[534,650]],clamp=t=>Math.max(0,Math.min(1,t)),ease=t=>{t=clamp(t);return t*t*(3-2*t);};
 let running=null;
 function homography(from,to){const rows=[];for(let i=0;i<4;i++){const [x,y]=from[i],[u,v]=to[i];rows.push([x,y,1,0,0,0,-u*x,-u*y,u],[0,0,0,x,y,1,-v*x,-v*y,v]);}for(let k=0;k<8;k++){let pivot=k;for(let j=k+1;j<8;j++)if(Math.abs(rows[j][k])>Math.abs(rows[pivot][k]))pivot=j;[rows[k],rows[pivot]]=[rows[pivot],rows[k]];const d=rows[k][k];if(Math.abs(d)<1e-10)throw Error('封面坐标无法求解');for(let c=k;c<9;c++)rows[k][c]/=d;for(let r=0;r<8;r++)if(r!==k){const f=rows[r][k];for(let c=k;c<9;c++)rows[r][c]-=f*rows[k][c];}}return [...rows.map(r=>r[8]),1];}
 const matrix=h=>`matrix3d(${[h[0],h[3],0,h[6],h[1],h[4],0,h[7],0,0,1,0,h[2],h[5],0,1].join(',')})`;
 const prefix=(html,key)=>html.replaceAll('id="clip-',`id="${key}-clip-`).replaceAll('url(#clip-',`url(#${key}-clip-`);
 function rectangles(){
  const reader=$('#reader'),closed=$('#closed'),rs=reader.hidden,cs=closed.hidden,rv=reader.style.visibility,cv=closed.style.visibility;
  reader.style.visibility='hidden';closed.style.visibility='hidden';reader.hidden=false;closed.hidden=false;
  // PageFlip applies a newly selected leaf's DOM styles on its next render frame. Measure the
  // stable paper window instead, fitting the same landscape page ratio even before that frame.
  const slot=$('#pages-slot').getBoundingClientRect(),ratio=REPORT_DATA.design.pageWidth/REPORT_DATA.design.pageHeight;
  const width=Math.min(slot.width/2,slot.height*ratio),height=width/ratio,x=slot.x+(slot.width-width*2)/2,y=slot.y+(slot.height-height)/2;
  const result={assembly:$('#assembly').getBoundingClientRect(),cover:$('#cover-open').getBoundingClientRect(),stage:$('#stage').getBoundingClientRect(),left:{x,y,width,height},right:{x:x+width,y,width,height}};
  reader.hidden=rs;closed.hidden=cs;reader.style.visibility=rv;closed.style.visibility=cv;return result;
 }
 async function animate({opening,left,right,leftId,rightId,reduced=false}){
  if(running)throw Error('封面动画正在执行');
  const root=$('#binding-scene'),rect=rectangles(),scale=rect.assembly.width/1080;
  const placement=box=>`x="${(box.x-rect.assembly.x)/scale}" y="${(box.y-rect.assembly.y)/scale}" width="${box.width/scale}" height="${box.height/scale}"`;
  const start=quad.map(([x,y])=>[(rect.cover.left-rect.assembly.left+x*rect.cover.width/530)/scale,(rect.cover.top-rect.assembly.top+y*rect.cover.height/650)/scale]);
  const stackMatrix=matrix(homography(quad,face)),titleMatrix=matrix(homography(quad,face.map(([x,y])=>[x-534,y])));
  root.style.left=(rect.assembly.left-rect.stage.left)+'px';root.style.top=(rect.assembly.top-rect.stage.top)+'px';root.style.width=rect.assembly.width+'px';root.style.height=rect.assembly.height+'px';
  root.innerHTML=`<div class="binding-camera" style="transform:scale(${scale})"><div class="binding-pose"><div class="binding-right"><svg viewBox="0 0 1080 670"><image href="assets/book-base.png" width="1080" height="670"/><svg ${placement(rect.right)} viewBox="0 0 762 925">${prefix(right,'binding-right')}</svg></svg></div><div class="binding-shade"></div><img class="binding-old-stack" src="assets/binding-stack.png" draggable="false" style="transform:${stackMatrix}"><div class="binding-board"><div class="binding-front binding-face"><svg viewBox="0 0 534 670"><defs><clipPath id="binding-front-shape"><path d="M0 14H504Q527 14 527 38V628Q527 650 504 650H0Z"/></clipPath></defs><g clip-path="url(#binding-front-shape)"><image href="assets/binding-front.png" x="0" y="14" width="527" height="636" preserveAspectRatio="none"/></g></svg><div class="binding-cover-title" style="transform:translateZ(.15px) ${titleMatrix}"><svg viewBox="0 0 530 650"><text x="262" y="185" text-anchor="middle" transform="rotate(-9 262 185)" font-family="ReportHand" font-size="26" fill="#66523b">进步报告</text></svg></div><div class="binding-cloth-light"></div></div><div class="binding-back binding-face"><svg viewBox="0 0 534 670"><image href="assets/book-base.png" width="1080" height="670"/><svg ${placement(rect.left)} viewBox="0 0 762 925">${prefix(left,'binding-left')}</svg></svg><div class="binding-paper-light"></div></div><div class="binding-board-edge"></div></div></div></div>`;
  const pose=root.querySelector('.binding-pose'),board=root.querySelector('.binding-board'),rightBody=root.querySelector('.binding-right'),oldStack=root.querySelector('.binding-old-stack'),shade=root.querySelector('.binding-shade'),clothLight=root.querySelector('.binding-cloth-light'),paperLight=root.querySelector('.binding-paper-light');
  const render=position=>{const p=clamp(position),travel=ease(p/.72),angle=-180*ease((p-.065)/.935),lift=Math.sin(-angle*Math.PI/180),corners=start.map((point,i)=>point.map((v,k)=>v+(face[i][k]-v)*travel));pose.style.transform=matrix(homography(face,corners));board.style.transform=`rotateY(${angle}deg)`;root.querySelector('.binding-front').style.transform=`translateZ(${lift*2}px)`;root.querySelector('.binding-back').style.transform=`rotateY(180deg) translateZ(${lift*2}px)`;rightBody.style.opacity=String(ease((p-.03)/.2));oldStack.style.opacity=String(1-ease((p-.2)/.2));shade.style.opacity=String(lift*.16);shade.style.transform=`scaleX(${.12+.88*Math.abs(Math.cos(angle*Math.PI/180))})`;shade.style.filter=`blur(${4+lift*16}px)`;clothLight.style.opacity=String(lift*.12);paperLight.style.opacity=String(lift*.075);$('#closed .cover-copy').style.opacity=String(1-ease(p/.2));root.dataset.progress=p.toFixed(4);root.dataset.angle=angle.toFixed(2);};
  root.hidden=false;render(opening?0:1);
  const images=[...root.querySelectorAll('img')];await Promise.all(images.map(i=>i.decode().catch(()=>{})));
  return new Promise(resolve=>{const duration=reduced?0:1480,started=performance.now();let frame=0,finished=false;
   const finish=()=>{if(finished)return;finished=true;cancelAnimationFrame(frame);render(opening?1:0);root.hidden=true;running=null;resolve();};
   running={finish,opening,root};
   function tick(now){const t=duration?clamp((now-started)/duration):1;render(opening?t:1-t);if(t<1)frame=requestAnimationFrame(tick);else finish();}
   frame=requestAnimationFrame(tick);
  });
 }
 window.BookBinding=Object.freeze({animate,finish:()=>running?.finish(),get active(){return !!running;}});
})();
