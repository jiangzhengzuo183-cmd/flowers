// Local displacement field; source texture is always the same separated ink image.
window.InkFlow = class InkFlow {
  constructor(canvas, image, settings) {
    this.resources={shaders:[],textures:[],buffers:[],programs:[]};this.lifecycle=new AbortController();this.disposed=false;
    this.canvas=canvas; this.image=image; this.settings=settings;
    this.w=128; this.h=112; this.field=new Float32Array(this.w*this.h*2);
    this.inertia=new Float32Array(this.field.length);
    this.encodingRange=Math.max(.08,settings.maxDisplacement*settings.aspect*1.1);
    this.bytes=new Uint8Array(this.w*this.h*4); this.pending=[]; this.last=null;
    this.energy=0; this.maxDisplacement=0; this.running=false; this.ready=false; this.frame=0;
    const g=this.gl=canvas.getContext('webgl',{alpha:true,premultipliedAlpha:true,depth:false,antialias:false});
    if(!g) return;
    try {
      const compile=(type,src)=>{const s=g.createShader(type);this.resources.shaders.push(s);g.shaderSource(s,src);g.compileShader(s);if(!g.getShaderParameter(s,g.COMPILE_STATUS))throw Error(g.getShaderInfoLog(s));return s;};
      const p=g.createProgram();this.resources.programs.push(p);
      g.attachShader(p,compile(g.VERTEX_SHADER,'attribute vec2 p; varying vec2 uv; void main(){uv=p*.5+.5;gl_Position=vec4(p,0.,1.);}'));
      g.attachShader(p,compile(g.FRAGMENT_SHADER,`precision highp float; varying vec2 uv;
        uniform sampler2D source; uniform sampler2D flow; uniform float enabled; uniform float encodingRange;
        void main(){vec2 v=vec2(uv.x,1.-uv.y);vec4 f=texture2D(flow,v);
        vec2 d=(vec2(dot(f.rg,vec2(65280.,255.)),dot(f.ba,vec2(65280.,255.)))/65535.*2.-1.)*encodingRange;
        vec2 q=v-d*enabled;if(q.x<0.||q.y<0.||q.x>1.||q.y>1.){gl_FragColor=vec4(0.);return;}
        gl_FragColor=texture2D(source,q);}`));
      g.linkProgram(p);if(!g.getProgramParameter(p,g.LINK_STATUS))throw Error(g.getProgramInfoLog(p));g.useProgram(p);
      const b=g.createBuffer();this.resources.buffers.push(b);g.bindBuffer(g.ARRAY_BUFFER,b);g.bufferData(g.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),g.STATIC_DRAW);
      const loc=g.getAttribLocation(p,'p');g.enableVertexAttribArray(loc);g.vertexAttribPointer(loc,2,g.FLOAT,false,0,0);
      const tex=unit=>{g.activeTexture(g.TEXTURE0+unit);const t=g.createTexture();this.resources.textures.push(t);g.bindTexture(g.TEXTURE_2D,t);for(const a of[g.TEXTURE_WRAP_S,g.TEXTURE_WRAP_T])g.texParameteri(g.TEXTURE_2D,a,g.CLAMP_TO_EDGE);for(const a of[g.TEXTURE_MIN_FILTER,g.TEXTURE_MAG_FILTER])g.texParameteri(g.TEXTURE_2D,a,g.LINEAR);return t;};
      tex(0);g.pixelStorei(g.UNPACK_PREMULTIPLY_ALPHA_WEBGL,true);g.texImage2D(g.TEXTURE_2D,0,g.RGBA,g.RGBA,g.UNSIGNED_BYTE,image);g.pixelStorei(g.UNPACK_PREMULTIPLY_ALPHA_WEBGL,false);
      g.uniform1i(g.getUniformLocation(p,'source'),0);
      this.flowTexture=tex(1);g.texImage2D(g.TEXTURE_2D,0,g.RGBA,this.w,this.h,0,g.RGBA,g.UNSIGNED_BYTE,this.bytes);g.uniform1i(g.getUniformLocation(p,'flow'),1);
      g.uniform1f(g.getUniformLocation(p,'encodingRange'),this.encodingRange);
      this.enabled=g.getUniformLocation(p,'enabled');g.disable(g.BLEND);g.clearColor(0,0,0,0);this.ready=true;
      canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();this.ready=false;this.stop();canvas.closest('.card')?.classList.remove('flow-ready');},{signal:this.lifecycle.signal});
    } catch { this.ready=false; }
  }
  destroy(){
    if(this.disposed)return;this.disposed=true;this.stop();this.lifecycle.abort();
    const g=this.gl;
    if(g){
      for(const x of this.resources.textures)g.deleteTexture(x);
      for(const x of this.resources.buffers)g.deleteBuffer(x);
      for(const x of this.resources.programs)g.deleteProgram(x);
      for(const x of this.resources.shaders)g.deleteShader(x);
      g.getExtension('WEBGL_lose_context')?.loseContext();
    }
    for(const key of Object.keys(this.resources))this.resources[key]=[];
    this.ready=false;this.field=new Float32Array(0);this.inertia=new Float32Array(0);this.bytes=new Uint8Array(0);
  }
  move(x,y,t) {
    if(!this.running)return;
    if(this.last){
      const dx=x-this.last.x,dy=y-this.last.y,len=Math.hypot(dx,dy/this.settings.aspect);
      const speed=Math.min(3,len/Math.max(.008,(t-this.last.t)/1000));
      const n=Math.min(32,Math.max(1,Math.ceil(len/.012)));
      for(let j=1;j<=n;j++)this.pending.push({x:this.last.x+dx*j/n,y:this.last.y+dy*j/n,dx:dx/n,dy:dy/n,speed});
      if(this.pending.length>256)this.pending.splice(0,this.pending.length-256);
    }
    this.last={x,y,t};
  }
  moveClient(x,y,t){
    const r=this.canvas.getBoundingClientRect();
    // Rebase the previous screen point into the current, animated card bounds.
    // A changing zoom must not masquerade as mouse motion or offset the splat.
    if(this.last&&this.lastClient){this.last.x=(this.lastClient.x-r.left)/r.width;this.last.y=(this.lastClient.y-r.top)/r.height;}
    this.move((x-r.left)/r.width,(y-r.top)/r.height,t);
    this.lastClient={x,y};
  }
  leave(){this.last=null;this.lastClient=null;}
  start(){if(!this.ready)return;this.stop();this.running=true;this.previous=performance.now();this.render(this.previous);}
  stop(){this.running=false;cancelAnimationFrame(this.frame);this.field.fill(0);this.inertia.fill(0);this.pending=[];this.leave();this.energy=0;this.maxDisplacement=0;}
  render(now){
    if(!this.running||!this.ready)return;
    const s=this.settings,g=this.gl,dt=Math.min(.05,Math.max(.001,(now-this.previous)/1000));this.previous=now;
    const decay=Math.exp(-s.recovery*dt),ratio=s.aspect;
    const momentumDecay=Math.exp(-dt/Math.max(.001,s.inertia));
    for(let i=0;i<this.field.length;i++){
      const v=this.field[i]*decay+this.inertia[i]*(1-momentumDecay);
      this.field[i]=Math.abs(v)<.000003?0:v;
      this.inertia[i]*=momentumDecay;
    }
    const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches?s.reducedStrength:1;
    for(const p of this.pending){
      const r=s.radius,r2=r*r,gain=s.strength*(1+p.speed*s.speedInfluence)*reduced;
      for(let y=Math.max(0,Math.floor((p.y-r*ratio)*this.h));y<Math.min(this.h,(p.y+r*ratio)*this.h);y++){
        for(let x=Math.max(0,Math.floor((p.x-r)*this.w));x<Math.min(this.w,(p.x+r)*this.w);x++){
          const ox=(x+.5)/this.w-p.x,oy=((y+.5)/this.h-p.y)/ratio,d=(ox*ox+oy*oy)/r2;
          if(d>=1)continue;const weight=(1-d)**3*gain,bend=ox/r*.2,i=(y*this.w+x)*2;
          const fx=(p.dx-p.dy*bend)*weight,fy=(p.dy+p.dx*bend)*weight;
          this.field[i]+=fx*.8;this.field[i+1]+=fy*.8;
          this.inertia[i]+=fx*.2;this.inertia[i+1]+=fy*.2;
        }
      }
    }
    this.pending=[];this.energy=0;this.maxDisplacement=0;
    for(let i=0;i<this.field.length;i+=2){
      let dx=this.field[i],dy=this.field[i+1],len=Math.hypot(dx,dy/ratio);
      // Saturate only the displayed displacement. Applying a hard clamp to the
      // simulation every frame causes a sudden change of slope and loses inertia.
      const limited=s.maxDisplacement*Math.tanh(len/s.maxDisplacement);
      if(len>0){dx*=limited/len;dy*=limited/len;}
      this.maxDisplacement=Math.max(this.maxDisplacement,limited);
      this.energy+=dx*dx+dy*dy;
      const a=Math.round((dx/this.encodingRange*.5+.5)*65535),b=Math.round((dy/this.encodingRange*.5+.5)*65535);
      this.bytes[i*2]=a>>8;this.bytes[i*2+1]=a&255;this.bytes[i*2+2]=b>>8;this.bytes[i*2+3]=b&255;
    }
    const r=this.canvas.getBoundingClientRect(),dpr=Math.min(devicePixelRatio||1,2),w=Math.max(1,Math.round(r.width*dpr)),h=Math.max(1,Math.round(r.height*dpr));
    if(this.canvas.width!==w||this.canvas.height!==h){this.canvas.width=w;this.canvas.height=h;g.viewport(0,0,w,h);}
    g.activeTexture(g.TEXTURE1);g.bindTexture(g.TEXTURE_2D,this.flowTexture);g.texSubImage2D(g.TEXTURE_2D,0,0,0,this.w,this.h,g.RGBA,g.UNSIGNED_BYTE,this.bytes);
    g.uniform1f(this.enabled,this.energy>0?1:0);g.clear(g.COLOR_BUFFER_BIT);g.drawArrays(g.TRIANGLES,0,6);
    this.frame=requestAnimationFrame(t=>this.render(t));
  }
};
