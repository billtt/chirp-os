using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using ChirpOS.Core;
namespace ChirpOS;

// Extract alpha once. Hover and label placement must not perform GDI pixel reads
// on the UI/animation thread for every mouse move or displayed frame.
internal sealed class AtlasHitMap {
    readonly bool[][] masks;
    readonly int[] tops;
    readonly Box[] bounds;
    public AtlasHitMap(Bitmap atlas,int frameCount) {
        masks=new bool[frameCount][];tops=new int[frameCount];bounds=new Box[frameCount];
        var data=atlas.LockBits(new Rectangle(0,0,atlas.Width,atlas.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
        try {
            var rows=new byte[atlas.Height][];
            for(var y=0;y<atlas.Height;y++) {
                rows[y]=new byte[atlas.Width*4];
                Marshal.Copy(IntPtr.Add(data.Scan0,y*data.Stride),rows[y],0,rows[y].Length);
            }
            for(var f=0;f<frameCount;f++) {
                var mask=new bool[48*48];var top=-1;
                for(var y=0;y<48;y++)for(var x=0;x<48;x++) {
                    var opaque=rows[y*atlas.Height/48][(f*atlas.Height+x*atlas.Height/48)*4+3]>0;
                    mask[y*48+x]=opaque;if(opaque && top<0)top=y;
                }
                masks[f]=mask;tops[f]=Math.Max(0,top);
                var pixels=Enumerable.Range(0,48*48).Where(i=>mask[i]).ToArray();
                if(pixels.Length>0) {
                    var left=pixels.Min(i=>i%48);var right=pixels.Max(i=>i%48);var bottom=pixels.Max(i=>i/48);
                    bounds[f]=new(left,tops[f],right-left+1,bottom-tops[f]+1);
                }
            }
        }finally{atlas.UnlockBits(data);}
    }
    public bool Contains(int frame,int x,int y)=>x>=0 && x<48 && y>=0 && y<48 && masks[frame][y*48+x];
    public int Top(int frame)=>tops[frame];
    public Box Bounds(int frame)=>bounds[frame];
    public double TopCenter(int frame) {
        var crown=Enumerable.Range(0,48).Where(x=>Contains(frame,x,tops[frame])).ToArray();
        return crown.Length==0?24:crown.Average()+.5;
    }
}
