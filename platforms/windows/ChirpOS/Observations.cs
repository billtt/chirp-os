using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using ChirpOS.Core;
namespace ChirpOS;

internal sealed partial class Desktop {
    internal LifeList LifeList=new();
    bool lifeListAvailable=true, observationIntroductionPending, observationIntroductionVisible;
    int feedbackWidth=140;
    readonly ObservationVisits<Bird> observationVisits=new();
    readonly ObservationInteraction<Bird> observationInteraction=new();
    readonly Overlay observationHearts=new();
    Bird? heartsBird;
    double heartsStarted=-10;
    readonly Overlay cameraTarget=new(true), observationFeedback=new(), clickFlash=new();
    double clickFlashStarted=-10;
    Point clickFlashPoint;
    double feedbackStarted=-10;
    string feedbackText="";
    bool feedbackNew;
    Bird? feedbackBird;
    Point feedbackPoint;
    static string LifeListPath=>Path.Combine(Program.DataFolder,"life-list.json");
    internal Species EffectiveProfile(Species species)=>LifeList.Enabled?species:Settings.Resolve(species);
    void LoadLifeList() {
        try {
            var loaded=LifeList.Load(LifeListPath);
            var introduce=loaded.PrepareIntroduction();
            if(introduce)loaded.Save(LifeListPath);
            LifeList=loaded;observationIntroductionPending=introduce;
        }
        catch(Exception error){lifeListAvailable=false;Error(error);}
        cameraTarget.Photograph=Photograph;
        cameraTarget.CanPhotograph=()=>CanPhotograph(HitBird());
    }
    void ShowObservationIntroduction() {
        if(!observationIntroductionPending)return;
        observationIntroductionPending=false;
        observationIntroductionVisible=true;
        try { MessageBox.Show(T("将鼠标移到小鸟身上，点击取景框即可记录。首次发现的鸟种会加入 Life List（鸟种记录）。\n\n观鸟模式下鸟种设置不生效。你可以随时在菜单中关闭“观鸟模式”，恢复自己的设置，已有记录会保留。", "Hover over a bird and click the viewfinder to record it. Newly discovered species join your Life List.\n\nCustom bird settings do not apply in birdwatching mode. Turn it off anytime in the menu to restore your settings. Your observations will be kept."), T("欢迎进入观鸟模式", "Welcome to birdwatching mode"),MessageBoxButtons.OK,MessageBoxIcon.Information); }
        finally { observationIntroductionVisible=false; }
    }
    void ToggleObservations() {
        if(!lifeListAvailable)return;
        var next=LifeList.Copy();next.Enabled=!next.Enabled;
        try{next.Save(LifeListPath);}catch(Exception e){Error(e);return;}
        LifeList=next;observationVisits.Reset();observationInteraction.Reset();observationHearts.Hide();heartsBird=null;feedbackBird=null;cameraTarget.Hide();observationFeedback.Hide();clickFlash.Hide();clickFlashStarted=-10;feedbackStarted=-10;
        if(next.Enabled){foreach(var (bird,_) in flock)Depart(bird);}
        BuildMenu();settingsWindow?.RefreshMode();
    }
    bool CanPhotograph(Bird? bird) => LifeList.Enabled && !observationIntroductionVisible && bird!=null && observationVisits.Contains(bird)
        && !menu.Visible && !Application.OpenForms.Cast<Form>().Any(f=>f is not Overlay && f.Visible && f.Bounds.Contains(Cursor.Position));
    void UpdateCamera(Bird? bird,double now) {
        UpdateClickFlash(now);
        UpdateHearts(now);
        // Keep the target during a held click while feedback continues animating.
        if(!cameraTarget.Capture) {
            if(CanPhotograph(bird) && Control.MouseButtons==MouseButtons.None) {
                var p=Cursor.Position;
                using var bitmap=new Bitmap(28,28,PixelFormat.Format32bppPArgb);
                using(var g=Graphics.FromImage(bitmap)) {
                    // A nearly transparent interior receives the click; corners form the viewfinder.
                    g.Clear(Color.FromArgb(1,0,0,0));
                    foreach(var (x,y,dx,dy) in new[]{(3,3,1,1),(24,3,-1,1),(3,24,1,-1),(24,24,-1,-1)}) {
                        using var shadow=new Pen(Color.Black,3);using var light=new Pen(Color.White,1);
                        var points=new[]{new Point(x+dx*6,y),new Point(x,y),new Point(x,y+dy*6)};
                        g.DrawLines(shadow,points);g.DrawLines(light,points);
                    }
                }
                cameraTarget.RenderBitmap(bitmap,p.X-14,p.Y-14);
            }else cameraTarget.Hide();
        }
        var age=now-feedbackStarted;
        if(age>=1.2 || !LifeList.Enabled || feedbackBird==null || !flock.Any(x=>ReferenceEquals(x.Bird,feedbackBird))){observationFeedback.Hide();return;}
        using var feedback=new Bitmap(feedbackWidth,110,PixelFormat.Format32bppPArgb);
        using(var g=Graphics.FromImage(feedback)) {
            var alpha=(int)(255*Math.Clamp((1.2-age)*3,0,1));
            using var background=new SolidBrush(Color.FromArgb((int)(alpha*.8),25,27,31));
            using var measureFont=new Font("Segoe UI",10);
            var textWidth=Math.Min(feedbackWidth-8,(int)Math.Ceiling(g.MeasureString(feedbackText,measureFont).Width)+20);
            PositionFeedback(feedbackBird,textWidth);
            var textX=(feedbackWidth-textWidth)/2;
            var rise=(float)age*16;
            g.FillRectangle(background,textX,48-rise,textWidth,27);
            using var font=new Font("Segoe UI",10);using var ink=new SolidBrush(Color.FromArgb(alpha,Color.White));
            using var format=new StringFormat{Alignment=StringAlignment.Center};
            g.DrawString(feedbackText,font,ink,new RectangleF(textX+4,52-rise,textWidth-8,25),format);
            if(feedbackNew)for(var i=0;i<16;i++) {
                var colors=new[]{Color.HotPink,Color.Gold,Color.Turquoise,Color.CornflowerBlue,Color.Orange};
                using var confetti=new SolidBrush(Color.FromArgb(alpha,colors[i%colors.Length]));
                var radius=12+age*42;g.FillRectangle(confetti,feedbackWidth/2+(float)(Math.Cos(i*2.4)*radius),65+(float)(Math.Sin(i*2.4)*radius-age*12),4,3);
            }
        }
        observationFeedback.RenderBitmap(feedback,feedbackPoint.X,feedbackPoint.Y);
    }
    void UpdateClickFlash(double now) {
        var age=now-clickFlashStarted;
        if(!LifeList.Enabled || age>=.2){clickFlash.Hide();return;}
        using var bitmap=new Bitmap(32,32,PixelFormat.Format32bppPArgb);
        using(var g=Graphics.FromImage(bitmap)) {
            using var ink=new Pen(Color.FromArgb((int)(255*Math.Clamp(1-age/.2,0,1)),Color.White),2);
            g.DrawRectangle(ink,2,2,28,28);
        }
        clickFlash.RenderBitmap(bitmap,clickFlashPoint.X-16,clickFlashPoint.Y-16);
    }
    void UpdateHearts(double now) {
        var bird=heartsBird;var age=now-heartsStarted;
        if(!LifeList.Enabled || bird==null || age>=ObservationHearts.Duration || !flock.Any(x=>ReferenceEquals(x.Bird,bird))) {
            observationHearts.Hide();heartsBird=null;return;
        }
        var map=hitMaps[bird.Species.Id];var scale=Scale(bird);
        var top=bird.Position.Y+(Math.Min(map.Top(frames[bird.Frame]),map.Top(frames["stand"]))+bird.Hop-39)*scale;
        var crown=map.TopCenter(frames["stand"]);
        var headX=bird.Position.X+((bird.Right?crown:48-crown)-(bird.Right?29:19))*scale;
        if(bird.Blockers(surfaces).Any(r=>headX>=r.X && headX<r.Right && top+1>=r.Y && top+1<r.Bottom)) {
            observationHearts.Hide();return;
        }
        using var bitmap=new Bitmap(120,100,PixelFormat.Format32bppPArgb);
        using(var g=Graphics.FromImage(bitmap)) {
            g.SmoothingMode=SmoothingMode.AntiAlias;
            for(var i=0;i<ObservationHearts.Count;i++) {
                var particle=ObservationHearts.Particle(i,age);var size=(float)particle.Size;
                var x=60+particle.X;var y=99-particle.Y;
                using var heart=new GraphicsPath();
                heart.AddBezier(0,0,-.2f,-.22f,-.62f,-.4f,-.5f,-.65f);
                heart.AddBezier(-.5f,-.65f,-.42f,-1,-.12f,-1,0,-.72f);
                heart.AddBezier(0,-.72f,.12f,-1,.42f,-1,.5f,-.65f);
                heart.AddBezier(.5f,-.65f,.62f,-.4f,.2f,-.22f,0,0);heart.CloseFigure();
                using var transform=new Matrix(size,0,0,size,(float)x,(float)y);heart.Transform(transform);
                var alpha=(int)(255*particle.Opacity);
                using var ink=new SolidBrush(Color.FromArgb(alpha,Color.HotPink));g.FillPath(ink,heart);
            }
        }
        observationHearts.RenderBitmap(bitmap,(int)Math.Round(headX)-60,(int)Math.Floor(top-ObservationHearts.Clearance(scale))-100);
    }
    Box FeedbackBounds(Bird bird) {
        var map=hitMaps[bird.Species.Id];var current=map.Bounds(frames[bird.Frame]);var standing=map.Bounds(frames["stand"]);
        var left=Math.Min(current.X,standing.X);var right=Math.Max(current.Right,standing.Right);
        var top=Math.Min(current.Y,standing.Y);var bottom=Math.Max(current.Bottom,standing.Bottom);var scale=Scale(bird);
        return new(bird.Position.X+((bird.Right?left:48-right)-(bird.Right?29:19))*scale,
            bird.Position.Y+(top+bird.Hop-39)*scale,(right-left)*scale,(bottom-top)*scale);
    }
    void PositionFeedback(Bird bird,int textWidth) {
        var screen=Screen.FromPoint(new((int)bird.Position.X,(int)bird.Position.Y)).WorkingArea;
        var placement=BirdFeedbackLayout.Label(FeedbackBounds(bird),new(screen.X,screen.Y,screen.Width,screen.Height),textWidth,27);
        feedbackPoint=new((int)Math.Round(placement.X+placement.W/2-feedbackWidth/2d),(int)Math.Floor(placement.Y)-48);
    }
    void Photograph() {
        var bird=HitBird();if(!CanPhotograph(bird))return;
        var isNew=false;
        string text;
        if(observationVisits.WasRecorded(bird!))text=Name(bird!.Species);
        else {
            var next=LifeList.Copy();isNew=next.Record(bird!.Species.Id);
            try{next.Save(LifeListPath);}catch(Exception e){cameraTarget.Hide();Error(e);return;}
            LifeList=next;observationVisits.Commit(bird);
            text=Name(bird.Species)+(isNew?T(" · 加新！", " · Lifer!"):" +1");
        }
        var now=clock.Elapsed.TotalSeconds;
        clickFlashPoint=Cursor.Position;clickFlashStarted=now;UpdateClickFlash(now);
        var reaction=observationInteraction.Click(bird!,now);
        if(reaction.Hearts){heartsBird=bird;heartsStarted=now;UpdateHearts(now);}
        if(!reaction.Label)return;
        feedbackText=text;feedbackNew=isNew;
        var p=Cursor.Position;var screen=Screen.FromPoint(p).WorkingArea;
        using(var measure=new Bitmap(1,1))using(var graphics=Graphics.FromImage(measure))using(var font=new Font("Segoe UI",10)) {
            feedbackWidth=Math.Min(screen.Width,Math.Max(140,(int)Math.Ceiling(graphics.MeasureString(feedbackText,font).Width)+28));
        }
        feedbackBird=bird;
        feedbackStarted=now;
    }
}
