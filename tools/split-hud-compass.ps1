Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
public static class HudCompassLayers {
 static float S(float a,float b,float x){float t=Math.Max(0,Math.Min(1,(x-a)/(b-a)));return t*t*(3-2*t);}
 static float Side(float x,float y,float ax,float ay,float bx,float by){float ex=bx-ax,ey=by-ay;return (ex*(y-ay)-ey*(x-ax))/(float)Math.Sqrt(ex*ex+ey*ey);}
 static float Blade(float x,float y){return Math.Min(Math.Min(Side(x,y,855,307,686,611),Side(x,y,686,611,463,790)),Math.Min(Side(x,y,463,790,593,535),Side(x,y,593,535,855,307)));}
 static bool Rose(float x,float y){float[] px={648,690,930,690,644,602,365,602},py={308,530,570,610,831,610,568,530};bool inside=false;for(int i=0,j=7;i<8;j=i++)if((py[i]>y)!=(py[j]>y)&&x<(px[j]-px[i])*(y-py[i])/(py[j]-py[i])+px[i])inside=!inside;return inside;}
 static float Arc(float x,float y){float dx=x-640,dy=y-574;float r=(float)Math.Sqrt(dx*dx+dy*dy),t=(float)Math.Atan2(dx,-dy);return S(399,405,r)*(1-S(463,469,r))*S(.10f,.14f,t)*(1-S(1.30f,1.35f,t));}
 static void Visit(int at,int w,int h,Action<int> fn){int x=at%w,y=at/w;if(x>0)fn(at-1);if(x+1<w)fn(at+1);if(y>0)fn(at-w);if(y+1<h)fn(at+w);}
 public static int[] Bounds(byte[] rgba,int w,int h){int l=w,t=h,r=0,b=0;for(int y=0;y<h;y++)for(int x=0;x<w;x++)if(rgba[(y*w+x)*4+3]>0){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);b=Math.Max(b,y);}l=Math.Max(0,l-3);t=Math.Max(0,t-3);r=Math.Min(w-1,r+3);b=Math.Min(h-1,b+3);return new int[]{l,t,r-l+1,b-t+1};}
 public static byte[][] Split(byte[] src,int w,int h){int n=w*h;int[] label=new int[n],q=new int[n];int serial=0,big=0,bigSize=0;
  for(int i=0;i<n;i++){if(label[i]!=0||src[i*4+3]<=32)continue;serial++;int head=0,tail=1;q[0]=i;label[i]=serial;while(head<tail){int k=q[head++];Visit(k,w,h,j=>{if(label[j]==0&&src[j*4+3]>32){label[j]=serial;q[tail++]=j;}});}if(tail>bigSize){bigSize=tail;big=serial;}}
  byte[] clean=(byte[])src.Clone();
  for(int i=0;i<n;i++){bool keep=label[i]==big;if(!keep&&src[i*4+3]>0)Visit(i,w,h,j=>{if(label[j]==big)keep=true;});if(!keep)clean[i*4+3]=0;}
  // Trim the original opaque silhouette inward, retaining a thinner original white rim.
  float[] distance=new float[n];for(int i=0;i<n;i++)distance[i]=clean[i*4+3]>128?10000:0;
  for(int y=0;y<h;y++)for(int x=0;x<w;x++){int i=y*w+x;if(x>0)distance[i]=Math.Min(distance[i],distance[i-1]+1);if(y>0){distance[i]=Math.Min(distance[i],distance[i-w]+1);if(x>0)distance[i]=Math.Min(distance[i],distance[i-w-1]+1.414214f);if(x+1<w)distance[i]=Math.Min(distance[i],distance[i-w+1]+1.414214f);}}
  for(int y=h-1;y>=0;y--)for(int x=w-1;x>=0;x--){int i=y*w+x;if(x+1<w)distance[i]=Math.Min(distance[i],distance[i+1]+1);if(y+1<h){distance[i]=Math.Min(distance[i],distance[i+w]+1);if(x>0)distance[i]=Math.Min(distance[i],distance[i+w-1]+1.414214f);if(x+1<w)distance[i]=Math.Min(distance[i],distance[i+w+1]+1.414214f);}}
  for(int i=0;i<n;i++)clean[i*4+3]=(byte)Math.Round(clean[i*4+3]*S(15.5f,16.5f,distance[i]));
  byte[][] result={new byte[src.Length],new byte[src.Length],new byte[src.Length],new byte[src.Length]};
  for(int y=0;y<h;y++)for(int x=0;x<w;x++){int p=(y*w+x)*4;float d=Blade(x,y),mask=S(-22,-12,d),sector=Arc(x,y);int sx=1217-y,sy=x-77;if(Blade(sx,sy)>-24){sx=y+77;sy=1217-x;}if(Blade(sx,sy)>-24){sx=Rose(x,y)?647:400;sy=Rose(x,y)?400:400;}int sample=(Math.Max(0,Math.Min(h-1,sy))*w+Math.Max(0,Math.Min(w-1,sx)))*4;
   for(int c=0;c<3;c++)result[0][p+c]=(byte)Math.Round(clean[p+c]*(1-mask)+src[sample+c]*mask);
   float vx=x-640,vy=y-574,rad=(float)Math.Sqrt(vx*vx+vy*vy);float paperScale=rad>0?Math.Min(400,rad)/rad:0;int ax=(int)Math.Round(640-vx*paperScale),ay=(int)Math.Round(574-vy*paperScale);int opposite=(Math.Max(0,Math.Min(h-1,ay))*w+Math.Max(0,Math.Min(w-1,ax)))*4;
   float line=1-S(2.2f,3.4f,Math.Abs(rad-430));int[] dark={37,44,48};for(int c=0;c<3;c++){float repair=src[opposite+c]*(1-line)+dark[c]*line;result[0][p+c]=(byte)Math.Round(result[0][p+c]*(1-sector)+repair*sector);}
   result[0][p+3]=clean[p+3];
   float needle=S(-.85f,.85f,d);float gold=S(.10f,.25f,(src[p+2]-src[p])/255f)*S(.05f,.15f,(src[p+1]-src[p])/255f);float dx=x-640,dy=y-574;float hub=1-S(35.5f,36.5f,(float)Math.Sqrt(dx*dx+dy*dy));
   for(int layer=1;layer<=3;layer++){for(int c=0;c<3;c++)result[layer][p+c]=src[p+c];float a=layer==1?needle:layer==2?sector*gold:hub;result[layer][p+3]=(byte)Math.Round(clean[p+3]*a);}
  }
  return result;
 }
}
"@
$folder=Join-Path $PSScriptRoot '../godot/assets/UI/HUD'
$compassSource=[System.Drawing.Bitmap]::FromFile((Join-Path $folder 'originals/指南针.png'))
$rect=[System.Drawing.Rectangle]::new(0,0,$compassSource.Width,$compassSource.Height)
$lock=$compassSource.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pixels=New-Object byte[] ($lock.Stride*$compassSource.Height)
[System.Runtime.InteropServices.Marshal]::Copy($lock.Scan0,$pixels,0,$pixels.Length)
$compassSource.UnlockBits($lock)
$layers=[HudCompassLayers]::Split($pixels,$compassSource.Width,$compassSource.Height)
$names=@('base','needle','arc','hub')
$regions=@{}
for($i=0;$i -lt 4;$i++){
 $output=[System.Drawing.Bitmap]::new($compassSource.Width,$compassSource.Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $lock=$output.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 [System.Runtime.InteropServices.Marshal]::Copy($layers[$i],0,$lock.Scan0,$layers[$i].Length)
 $output.UnlockBits($lock)
 if($i -eq 0){$bounds=@(0,0,$compassSource.Width,$compassSource.Height)}else{$bounds=[HudCompassLayers]::Bounds($layers[$i],$compassSource.Width,$compassSource.Height)}
 $crop=$output.Clone([System.Drawing.Rectangle]::new($bounds[0],$bounds[1],$bounds[2],$bounds[3]),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $crop.Save((Join-Path $folder ('slices/compass_'+$names[$i]+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
 $regions[$names[$i]]=@($bounds[0],$bounds[1],$bounds[2],$bounds[3])
 $crop.Dispose()
 $output.Dispose()
}
$compassSource.Dispose()
$json=$regions | ConvertTo-Json
$json | Set-Content -LiteralPath (Join-Path $folder 'slices/compass_regions.json') -Encoding utf8
("extends RefCounted"+[System.Environment]::NewLine+"const REGIONS := "+$json) | Set-Content -LiteralPath (Join-Path $folder 'slices/compass_regions.gd') -Encoding utf8
Write-Output 'Compass: four clean layers; original retained; white border thinned; detached specks removed.'
