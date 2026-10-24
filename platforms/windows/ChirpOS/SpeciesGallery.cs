using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Text.Json;
using ChirpOS.Core;
namespace ChirpOS;

internal sealed class SpeciesGallery:Form {
    readonly System.Windows.Forms.Timer timer=new(){Interval=33};
    readonly Dictionary<string,Bitmap> art=[];
    readonly Dictionary<string,int> frames;
    DateTime started=DateTime.UtcNow;
    GalleryAction action=GalleryAction.Resting;
    public SpeciesGallery(Desktop desktop) {
        Text=desktop.LifeList.Enabled ? desktop.T("Life List（鸟种记录）", "Life List") : desktop.T("图鉴","Field guide");ClientSize=new(900,690);MinimumSize=new(920,400);BackColor=Color.White;
        using(var stream=Program.Resource("art/manifest.json")){using var doc=JsonDocument.Parse(stream);frames=doc.RootElement.GetProperty("frames").EnumerateArray().Select((v,i)=>(v.GetString()!,i)).ToDictionary(x=>x.Item1,x=>x.i);}
        var scroll=new Panel{Dock=DockStyle.Fill,AutoScroll=true,BackColor=Color.White};Controls.Add(scroll);
        var grid=new FlowLayoutPanel{Location=new(0,0),Width=880,Height=((desktop.Species.Length+3)/4)*220,WrapContents=true,BackColor=Color.White,Margin=Padding.Empty};scroll.Controls.Add(grid);
        var actions=new FlowLayoutPanel{Dock=DockStyle.Top,Height=52,Padding=new Padding(12,10,0,0),BackColor=Color.White};Controls.Add(actions);
        var labels=new[]{desktop.T("休息","Rest"),desktop.T("飞行","Flight"),desktop.T("振翅","Flapping"),desktop.T("滑翔","Gliding"),desktop.T("着陆","Landing"),desktop.T("理羽","Preening"),desktop.T("其他","Other")};
        foreach(var value in Enum.GetValues<GalleryAction>()) {
            var button=new RadioButton{Text=labels[(int)value],Appearance=Appearance.Button,AutoSize=true,Checked=value==GalleryAction.Resting,TextAlign=ContentAlignment.MiddleCenter};
            button.CheckedChanged+=(_,_)=>{if(button.Checked){action=value;started=DateTime.UtcNow;foreach(Control cell in grid.Controls)cell.Invalidate();}};
            actions.Controls.Add(button);
        }
        double dpi=1,maxScale=1;int cellWidth=220,cellHeight=220;
        void LayoutBirds() {
            dpi=Native.DpiScale(Screen.FromControl(this));
            maxScale=desktop.Species.Max(s=>desktop.EffectiveProfile(s).Scale)*desktop.Settings.Scale*dpi;
            var width=Math.Max(220,(int)Math.Ceiling(48*maxScale)+32);
            var height=(int)Math.Ceiling(48*maxScale)+125;
            var columns=Math.Max(1,880/width);
            if(width==cellWidth && height==cellHeight && grid.Controls.Count>0)return;
            cellWidth=width;cellHeight=height;grid.SuspendLayout();
            grid.Width=Math.Max(880,cellWidth);grid.Height=((desktop.Species.Length+columns-1)/columns)*cellHeight;
            foreach(Control cell in grid.Controls)cell.Size=new(cellWidth,cellHeight);
            grid.ResumeLayout();
        }
        foreach(var species in desktop.Species) {
            using var stream=Program.Resource("art/"+species.Id+".png");using var image=Image.FromStream(stream);art[species.Id]=new Bitmap(image);
            var cell=new GalleryCell{Width=220,Height=220,Margin=Padding.Empty,BackColor=Color.White,Tag=species};grid.Controls.Add(cell);
            cell.Paint+=(_,e)=>{
                var record=desktop.LifeList.Enabled ? desktop.LifeList.Records.GetValueOrDefault(species.Id) : null;
                var hidden=desktop.LifeList.Enabled && record is null;
                var profile=desktop.EffectiveProfile(species);
                var scale=desktop.Settings.Scale*profile.Scale*dpi;
                var side=Math.Max(1,(int)Math.Ceiling(48*scale));
                var top=16+39*maxScale-39*scale;
                var labelY=(int)Math.Ceiling(48*maxScale)+24;
                var pose=desktop.LifeList.Enabled?"stand":GalleryPose.Frame(species.Id,(DateTime.UtcNow-started).TotalSeconds,profile.FlapFPS,action,profile.Speed);
                e.Graphics.InterpolationMode=InterpolationMode.NearestNeighbor;e.Graphics.PixelOffsetMode=PixelOffsetMode.Half;
                using var attributes=new ImageAttributes();
                if(hidden) attributes.SetColorMatrix(new ColorMatrix(new float[][]{[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,1,0],[.25f,.25f,.25f,0,1]}));
                var atlas=art[species.Id];
                e.Graphics.DrawImage(atlas,new Rectangle((cellWidth-side)/2,(int)Math.Round(top),side,side),frames[pose]*atlas.Height,0,atlas.Height,atlas.Height,GraphicsUnit.Pixel,attributes);
                TextRenderer.DrawText(e.Graphics,hidden?desktop.T("未记录", "Unrecorded"):desktop.Name(species),Font,new Rectangle(5,labelY,cellWidth-10,36),Color.Black,TextFormatFlags.HorizontalCenter|TextFormatFlags.WordBreak);
                var detail=record is not null ? desktop.T($"记录 {record.Count} 次",$"{record.Count} observations")+"\n"+desktop.T("首次：", "First: ")+record.FirstRecordedAt.ToLocalTime().ToString("g",System.Globalization.CultureInfo.GetCultureInfo(desktop.Settings.English?"en-US":"zh-CN")) : hidden?"":ActionName(pose,desktop);
                TextRenderer.DrawText(e.Graphics,detail,Font,new Rectangle(5,labelY+36,cellWidth-10,50),Color.DimGray,TextFormatFlags.HorizontalCenter|TextFormatFlags.WordBreak);
            };
        }
        LifeList? previousList=null;bool? previousEnglish=null;
        void RefreshRecords() {
            if(ReferenceEquals(previousList,desktop.LifeList) && previousEnglish==desktop.Settings.English)return;
            previousList=desktop.LifeList;previousEnglish=desktop.Settings.English;
            actions.Visible=!desktop.LifeList.Enabled;
            var count=desktop.Species.Count(s=>desktop.LifeList.Records.ContainsKey(s.Id));
            Text=desktop.LifeList.Enabled ? desktop.T($"Life List（鸟种记录）· {count} / {desktop.Species.Length} 种",$"Life List · {count} / {desktop.Species.Length} species") : desktop.T("图鉴", "Field guide");
            grid.SuspendLayout();
            var cells=grid.Controls.Cast<Control>().ToArray();
            var ordered=desktop.LifeList.Enabled ? cells.OrderByDescending(c=>desktop.LifeList.Records.GetValueOrDefault(((Species)c.Tag!).Id)?.FirstRecordedAt ?? DateTimeOffset.MinValue).ThenBy(c=>((Species)c.Tag!).Id,StringComparer.Ordinal).ToArray() : cells.OrderBy(c=>Array.IndexOf(desktop.Species,(Species)c.Tag!)).ToArray();
            for(var i=0;i<ordered.Length;i++){var cell=ordered[i];grid.Controls.SetChildIndex(cell,i);cell.Visible=true;}
            grid.ResumeLayout();
        }
        LayoutBirds();RefreshRecords();
        timer.Tick+=(_,_)=>{LayoutBirds();RefreshRecords();foreach(Control cell in grid.Controls)if(cell.Bounds.IntersectsWith(new Rectangle(0,-scroll.AutoScrollPosition.Y,grid.Width,scroll.ClientSize.Height)))cell.Invalidate();};timer.Start();
    }
    static string ActionName(string pose,Desktop d)=>pose.StartsWith("bank")?d.T("盘旋展翼","Banking"):pose.StartsWith("glide")?d.T("展开翅膀滑翔","Gliding"):pose=="bound"?d.T("收翅起伏飞行","Bounding"):pose.StartsWith("idle")?d.T("习性动作","Characteristic action"):pose.StartsWith("fly")?d.T("振翅飞行","Flapping flight"):pose.StartsWith("land")?d.T("着陆","Landing"):pose.StartsWith("preen")?d.T("理羽","Preening"):pose.StartsWith("peck")?d.T("啄击","Pecking"):pose.StartsWith("cling")?d.T("侧边停靠","Clinging"):pose.StartsWith("poop")?d.T("挤洗手液","Dropping"):pose=="stretch"?d.T("伸颈","Stretching"):pose=="shake"?d.T("抖毛","Shaking"):d.T("休息与张望","Resting & watching");
    protected override void Dispose(bool disposing){if(disposing){timer.Dispose();foreach(var image in art.Values)image.Dispose();}base.Dispose(disposing);}
    sealed class GalleryCell:Panel {public GalleryCell(){DoubleBuffered=true;}}
}
