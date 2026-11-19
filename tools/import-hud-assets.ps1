Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;using System.Collections.Generic;
public class HudPart {public int X,Y,W,H,Area;public byte[] Pixels;}
public class HudSplit {
 public static HudPart[] Split(byte[] src,int w,int h,int stride,int minimum){
  bool[] seen=new bool[w*h];var parts=new List<HudPart>();
  for(int y=0;y<h;y++)for(int x=0;x<w;x++){
   int at=y*w+x;if(seen[at]||src[y*stride+x*4+3]<160)continue;
   var cells=new List<int>();var q=new Queue<int>();q.Enqueue(at);seen[at]=true;
   int ax=x,bx=x,ay=y,by=y;
   while(q.Count>0){int k=q.Dequeue(),xx=k%w,yy=k/w;cells.Add(k);ax=Math.Min(ax,xx);bx=Math.Max(bx,xx);ay=Math.Min(ay,yy);by=Math.Max(by,yy);
    foreach(int j in new int[]{k-1,k+1,k-w,k+w}){if(j<0||j>=w*h||seen[j]||Math.Abs(j%w-xx)>1||src[(j/w)*stride+(j%w)*4+3]<160)continue;seen[j]=true;q.Enqueue(j);}}
   if(cells.Count<minimum)continue;
   ax=Math.Max(0,ax-2);ay=Math.Max(0,ay-2);bx=Math.Min(w-1,bx+2);by=Math.Min(h-1,by+2);
   var p=new HudPart{X=ax,Y=ay,W=bx-ax+1,H=by-ay+1,Area=cells.Count};p.Pixels=new byte[p.W*p.H*4];
   // Preserve source RGBA and antialiased fringe. Isolated background flecks aren't part of a glyph.
   foreach(int k in cells)for(int dy=-2;dy<=2;dy++)for(int dx=-2;dx<=2;dx++){
    int xx=k%w+dx,yy=k/w+dy;if(xx<ax||xx>bx||yy<ay||yy>by)continue;
    Array.Copy(src,yy*stride+xx*4,p.Pixels,((yy-ay)*p.W+xx-ax)*4,4);}
   parts.Add(p);
  }return parts.ToArray();
 }
}
"@
$root = Join-Path $PSScriptRoot '../godot/assets/UI/HUD'
$originals = Join-Path $root 'originals'
$out = Join-Path $root 'slices'
New-Item -ItemType Directory -Path $out -Force | Out-Null
function Read-Parts($file,$minimum){
 $im=[System.Drawing.Bitmap]::FromFile((Join-Path $originals $file))
 $bits=$im.LockBits([System.Drawing.Rectangle]::new(0,0,$im.Width,$im.Height),[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $data=New-Object byte[] ($bits.Stride*$im.Height)
 [System.Runtime.InteropServices.Marshal]::Copy($bits.Scan0,$data,0,$data.Length)
 $parts=[HudSplit]::Split($data,$im.Width,$im.Height,$bits.Stride,$minimum)
 $im.UnlockBits($bits);$im.Dispose();return $parts
}
function Save-Part($part,$name){
 $im=[System.Drawing.Bitmap]::new($part.W,$part.H,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $bits=$im.LockBits([System.Drawing.Rectangle]::new(0,0,$im.Width,$im.Height),[System.Drawing.Imaging.ImageLockMode]::WriteOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 [System.Runtime.InteropServices.Marshal]::Copy($part.Pixels,0,$bits.Scan0,$part.Pixels.Length)
 $im.UnlockBits($bits);$im.Save((Join-Path $out "$name.png"));$im.Dispose()
}
$digits=@(Read-Parts '计时字体素材/微信图片_20261118011039_943_22.png' 9000)
if($digits.Count -ne 12){throw "Expected 10 digits and 2 colon dots; found $($digits.Count)"}
$top=@($digits | Where-Object Y -lt 520 | Sort-Object X)
$bottom=@($digits | Where-Object { $_.Y -ge 520 -and $_.X -lt 1200 } | Sort-Object X)
for($i=0;$i -lt 6;$i++){Save-Part $top[$i] "digit_$i"}
for($i=0;$i -lt 4;$i++){Save-Part $bottom[$i] "digit_$($i+6)"}
$dots=@($digits | Where-Object X -ge 1200 | Sort-Object Y)
$colon=[HudPart]::new();$colon.W=116;$colon.H=336;$colon.Pixels=New-Object byte[] ($colon.W*$colon.H*4)
foreach($part in $dots){for($y=0;$y -lt $part.H;$y++){[Array]::Copy($part.Pixels,$y*$part.W*4,$colon.Pixels,(($y+$part.Y-590)*$colon.W)*4,$part.W*4)}}
Save-Part $colon 'colon'
$specs=@(@('体力值.png',50000,3,'bolt'),@('道具栏（空）.png',100000,3,'slot'),@('退出与重新开始.png',40000,2,'menu'))
foreach($spec in $specs){$parts=@(Read-Parts $spec[0] $spec[1] | Sort-Object X);if($parts.Count -ne $spec[2]){throw "Unexpected components in $($spec[0]): $($parts.Count)"};for($i=0;$i -lt $parts.Count;$i++){Save-Part $parts[$i] "$($spec[3])_$i"}}
$iconFiles=@(@('幸运兔脚.png','rabbit'),@('钱币.png','coin'),@('马蹄铁.png','horseshoe'),@('蛋糕.png','cake'),@('粉色药丸.png','capsule'))
foreach($spec in $iconFiles){$parts=@(Read-Parts $spec[0] 25000);if($parts.Count -ne 1){throw "Expected single icon in $($spec[0]); found $($parts.Count)"};Save-Part $parts[0] "icon_$($spec[1])"}
Get-ChildItem -LiteralPath $out -Filter '*.png' | Select-Object Name,Length
