using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using ChirpOS.Core;
namespace ChirpOS;
// One small layered window per bird keeps alpha compositing cheap even on 4K screens.
internal sealed class Overlay : Form
{
    readonly bool interactive;
    readonly bool raiseOnRender;
    public Action? Photograph;
    public Func<bool>? CanPhotograph;
    public void RenderBitmap(Bitmap image,int x,int y)=>Present(image,x,y);
    protected override bool ShowWithoutActivation => true;
    protected override CreateParams CreateParams { get { var c = base.CreateParams; c.ExStyle |= 0x80000 | (interactive?0:0x20) | 0x80 | 0x8000000; return c; } }
    public Overlay(bool interactive=false,bool raiseOnRender=true) { this.interactive=interactive; this.raiseOnRender=raiseOnRender; if(interactive)Cursor=Cursors.Cross; FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; StartPosition = FormStartPosition.Manual; AutoScaleMode = AutoScaleMode.None; Size = new(1, 1); }
    protected override void WndProc(ref Message m) { if (m.Msg == 0x21) { m.Result = (nint)3; return; } if (m.Msg == 0x84) { m.Result = interactive && CanPhotograph?.Invoke()==true ? (nint)1 : (nint)(-1); return; } base.WndProc(ref m); }
    protected override void OnMouseDown(MouseEventArgs e) { if(interactive && e.Button==MouseButtons.Left){Capture=true;Photograph?.Invoke();} base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { if(interactive)Capture=false; base.OnMouseUp(e); }
    public void Render(Bird bird, Bitmap atlas, int frame, double scale, IReadOnlyList<Surface> surfaces)
    {
        var size = Math.Max(1, (int)Math.Ceiling(48 * scale)); var x = (int)Math.Round(bird.Position.X - (bird.Right ? 29 : 19) * scale); var y = (int)Math.Round(bird.Position.Y + (bird.Hop - 39) * scale);
        using var bitmap = new Bitmap(size, size, PixelFormat.Format32bppPArgb);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.CompositingMode = CompositingMode.SourceCopy; g.Clear(Color.Transparent); g.InterpolationMode = InterpolationMode.NearestNeighbor; g.PixelOffsetMode = PixelOffsetMode.Half;
            using var region = new Region(new Rectangle(0, 0, size, size));
            foreach (var r in bird.Blockers(surfaces)) region.Exclude(new RectangleF((float)(r.X - x), (float)(r.Y - y), (float)r.W, (float)r.H));
            g.SetClip(region, CombineMode.Replace);
            if (!bird.Right) { g.TranslateTransform(size, 0); g.ScaleTransform(-1, 1); }
            g.DrawImage(atlas, new Rectangle(0, 0, size, size), new Rectangle(frame * atlas.Height, 0, atlas.Height, atlas.Height), GraphicsUnit.Pixel);
        }
        Present(bitmap,x,y);
    }
    public void RenderName(string name,Box bird) {
        using var font=new Font("Segoe UI",10);
        var measured=TextRenderer.MeasureText(name,font);
        var screen=Screen.FromPoint(new((int)(bird.X+bird.W/2),(int)(bird.Y+bird.H/2))).WorkingArea;
        var width=Math.Min(screen.Width,measured.Width+20);var height=measured.Height+8;
        using var bitmap=new Bitmap(width,height,PixelFormat.Format32bppPArgb);
        using(var g=Graphics.FromImage(bitmap)) {
            g.Clear(Color.FromArgb(220,25,27,31));
            g.TextRenderingHint=System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            g.DrawString(name,font,Brushes.White,8,3);
        }
        var placement=BirdFeedbackLayout.Label(bird,new(screen.X,screen.Y,screen.Width,screen.Height),width,height);
        Present(bitmap,(int)Math.Round(placement.X),(int)Math.Floor(placement.Y));
    }
    void Present(Bitmap bitmap,int x,int y) {
        var screenDc = Native.GetDC(0); var memoryDc = Native.CreateCompatibleDC(screenDc); var hb = bitmap.GetHbitmap(Color.FromArgb(0)); var old = Native.SelectObject(memoryDc, hb);
        try
        {
            var location = new Native.Point(x, y); var dimensions = new Native.Size(bitmap.Width, bitmap.Height); var source = new Native.Point(0, 0); var blend = new Native.Blend { Alpha = 255, Format = 1 };
            if (!Native.UpdateLayeredWindow(Handle, screenDc, ref location, ref dimensions, memoryDc, ref source, 0, ref blend, 2)) throw new System.ComponentModel.Win32Exception();
            var showing=!Visible;
            if (showing) Show();
            // Feedback windows keep their Z order between frames instead of
            // repeatedly overtaking each other while their bitmaps update.
            uint flags=0x1 | 0x2 | 0x10 | 0x40;
            if(!raiseOnRender && !showing)flags|=0x4; // SWP_NOZORDER
            Native.SetWindowPos(Handle, (nint)(-1), 0, 0, 0, 0, flags);
        }
        finally { Native.SelectObject(memoryDc, old); Native.DeleteObject(hb); Native.DeleteDC(memoryDc); Native.ReleaseDC(0, screenDc); }
    }
}
