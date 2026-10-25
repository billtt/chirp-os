namespace ChirpOS.Core;

// Coordinates are device pixels throughout. Divide the viewport, not a fixed
// unscaled canvas, so DPI scaling cannot introduce wrapping or horizontal scroll.
public readonly record struct GalleryLayout(int Width, int CellHeight, int Height, double MaxScale, double PreviewScale)
{
    public static GalleryLayout Calculate(int viewportWidth, int count, double dpi, double speciesScale)
    {
        var width=Math.Max(4,viewportWidth);
        var available=Math.Max(1,width/4-32*dpi);
        var requested=48*speciesScale*dpi;
        var preview=Math.Min(1,available/requested);
        var scale=speciesScale*dpi*preview;
        var height=(int)Math.Ceiling(48*scale+68*dpi);
        return new(width,height,((count+3)/4)*height,scale,preview);
    }
    public (int X,int Y,int Width,int Height) Cell(int index)
    {
        var column=index%4;var left=column*Width/4;var right=(column+1)*Width/4;
        return(left,index/4*CellHeight,right-left,CellHeight);
    }
}
