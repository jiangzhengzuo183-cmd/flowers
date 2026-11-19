$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Runtime,System.Collections,System.Runtime.InteropServices,System.Private.Windows.GdiPlus,System.Private.Windows.Core,System.Console -TypeDefinition @"
using System;using System.Drawing;using System.Drawing.Imaging;
// Historical output folder retained to avoid breaking references. No stroke expansion.
public class BoldTimerImport{
 public static void Build(string root){string source=System.IO.Path.Combine(root,"slices"),output=System.IO.Path.Combine(root,"timer_bold");System.IO.Directory.CreateDirectory(output);long r=0,g=0,bl=0,n=0;
 for(int i=0;i<11;i++)using(var b=new Bitmap(System.IO.Path.Combine(source,i==10?"colon.png":"digit_"+i+".png"))){for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){var c=b.GetPixel(x,y);if(c.A<240||c.R>150||c.G>140||c.B>130)continue;r+=c.R;g+=c.G;bl+=c.B;n++;}}
 byte red=(byte)Math.Round((double)r/n),green=(byte)Math.Round((double)g/n),blue=(byte)Math.Round((double)bl/n);
 for(int i=0;i<11;i++){string name=i==10?"colon.png":"digit_"+i+".png";using(var b=new Bitmap(System.IO.Path.Combine(source,name))){int w=b.Width,h=b.Height;var alpha=new byte[w*h];var grown=new byte[w*h];
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){var c=b.GetPixel(x,y);double ink=Math.Clamp((255.0-c.R)/(255.0-red),0,1);ink=ink*ink*(3-2*ink);alpha[y*w+x]=(byte)Math.Round(c.A*ink);}
 // Close only one-pixel internal pinholes. White perimeter stays transparent.
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){byte a=0;for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){int xx=x+dx,yy=y+dy;if(xx>=0&&xx<w&&yy>=0&&yy<h)a=Math.Max(a,alpha[yy*w+xx]);}grown[y*w+x]=a;}
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){byte a=255;for(int dy=-1;dy<=1;dy++)for(int dx=-1;dx<=1;dx++){int xx=x+dx,yy=y+dy;a=Math.Min(a,xx<0||xx>=w||yy<0||yy>=h?(byte)0:grown[yy*w+xx]);}b.SetPixel(x,y,Color.FromArgb(a,red,green,blue));}
 b.Save(System.IO.Path.Combine(output,name));}}
 Console.WriteLine("TIMER: original brown glyph weight, white outline removed; uniform RGB "+red+","+green+","+blue+"; no added bolding");}
}
"@
[BoldTimerImport]::Build((Join-Path $PSScriptRoot '../godot/assets/UI/HUD'))
