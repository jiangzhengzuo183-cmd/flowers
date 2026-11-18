$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Runtime,System.Collections,System.Runtime.InteropServices,System.Private.Windows.GdiPlus,System.Private.Windows.Core,System.Console -TypeDefinition @"
using System;using System.Drawing;using System.Drawing.Imaging;
public class BoldTimerImport{
 public static void Build(string root){string source=System.IO.Path.Combine(root,"slices"),output=System.IO.Path.Combine(root,"timer_bold");System.IO.Directory.CreateDirectory(output);long r=0,g=0,bl=0,n=0;for(int i=0;i<11;i++){using(var b=new Bitmap(System.IO.Path.Combine(source,i==10?"colon.png":"digit_"+i+".png"))){for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){var c=b.GetPixel(x,y);if(c.A<240||c.R>150||c.G>140||c.B>130)continue;r+=c.R;g+=c.G;bl+=c.B;n++;}}}byte red=(byte)Math.Round((double)r/n),green=(byte)Math.Round((double)g/n),blue=(byte)Math.Round((double)bl/n);
 for(int i=0;i<11;i++){string name=i==10?"colon.png":"digit_"+i+".png";using(var b=new Bitmap(System.IO.Path.Combine(source,name))){int w=b.Width,h=b.Height;var alpha=new byte[w*h];var dilated=new byte[w*h];for(int y=0;y<h;y++)for(int x=0;x<w;x++)alpha[y*w+x]=b.GetPixel(x,y).A;
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){byte maximum=0;for(int dy=-2;dy<=2;dy++)for(int dx=-2;dx<=2;dx++){int xx=x+dx,yy=y+dy;if(xx<0||xx>=w||yy<0||yy>=h)continue;maximum=Math.Max(maximum,alpha[yy*w+xx]);}dilated[y*w+x]=maximum;}
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){byte minimum=255;for(int dy=-2;dy<=2;dy++)for(int dx=-2;dx<=2;dx++){int xx=x+dx,yy=y+dy;minimum=Math.Min(minimum,xx<0||xx>=w||yy<0||yy>=h?(byte)0:dilated[yy*w+xx]);}b.SetPixel(x,y,Color.FromArgb(Math.Max(alpha[y*w+x],minimum),red,green,blue));}var ink=new byte[w*h];for(int y=0;y<h;y++)for(int x=0;x<w;x++)ink[y*w+x]=b.GetPixel(x,y).A;
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){byte minimum=255;for(int dy=-3;dy<=3;dy++)for(int dx=-3;dx<=3;dx++){if(dx*dx+dy*dy>9)continue;int xx=x+dx,yy=y+dy;minimum=Math.Min(minimum,xx<0||xx>=w||yy<0||yy>=h?(byte)0:ink[yy*w+xx]);}b.SetPixel(x,y,Color.FromArgb(minimum,red,green,blue));}b.Save(System.IO.Path.Combine(output,name));}}Console.WriteLine("TIMER brown="+red+","+green+","+blue+"; 11 glyphs retain original canvas bounds; interior alpha seams closed; solid medium-bold stroke, eased inward by 3 source pixels");}
}
"@
[BoldTimerImport]::Build((Join-Path $PSScriptRoot '../godot/assets/UI/HUD'))
