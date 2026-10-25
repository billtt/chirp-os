using ChirpOS.Core;
namespace ChirpOS;

internal sealed class SettingsWindow : Form
{
    readonly Desktop desktop;
    readonly Preferences draft;
    readonly List<TrackBar> sliders = [];
    readonly List<NumericUpDown> values = [];
    readonly List<CheckBox> locks = [];
    readonly List<NumericUpDown[]> details = [];
    readonly Label total = new();
    readonly Panel tabs = new() { Dock = DockStyle.Fill };
    readonly List<Panel> pages=[];
    readonly List<Button> categories=[];
    readonly FlowLayoutPanel general=new(){Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=true};
    readonly Label pageTitle=new(){AutoSize=true,Font=new Font("Segoe UI",16,FontStyle.Bold)};
    int selectedCategory=-1;
    readonly Label modeHint=new(){AutoSize=true,MaximumSize=new(850,0)};
    readonly TrackBar population=new(){Minimum=5,Maximum=20,TickFrequency=1,SmallChange=1,LargeChange=1};
    readonly Label populationValue=new(){AutoSize=true};
    readonly TrackBar globalSize=new(){Minimum=100,Maximum=200,TickStyle=TickStyle.None,SmallChange=1,LargeChange=10};
    readonly Label sizeValue=new(){AutoSize=true};
    readonly CheckBox login=new(){AutoSize=true};
    Button saveButton=null!,resetButton=null!;
    bool refreshing;

    public SettingsWindow(Desktop d)
    {
        desktop = d; draft = d.Clone();
        Text = d.T("设置", "Settings");
        Font=new Font("Segoe UI",9);
        AutoScaleDimensions = new SizeF(96,96); AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new(1040, 690); MinimumSize = new(960, 580); StartPosition = FormStartPosition.CenterScreen;
        using (var stream = Program.Resource("AppIcon.ico")) Icon = new Icon(stream);
        var shell=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=1,Margin=Padding.Empty};
        shell.ColumnStyles.Add(new(SizeType.Absolute,190));shell.ColumnStyles.Add(new(SizeType.Percent,100));Controls.Add(shell);
        var sidebar=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,Padding=new(12,24,12,12),BackColor=Color.FromArgb(238,240,243)};
        sidebar.Controls.Add(new Label{Text=d.T("设置","Settings"),Font=new Font(Font.FontFamily,13,FontStyle.Bold),AutoSize=true,Margin=new(8,0,0,24)});
        foreach(var (title,index) in new[]{(d.T("通用","General"),-1),(d.T("鸟种概率","Probabilities"),0),(d.T("鸟种设置","Bird settings"),1)}) {
            var button=new Button{Text=title,Tag=index,Width=160,Height=40,TextAlign=ContentAlignment.MiddleLeft,FlatStyle=FlatStyle.Flat,Margin=new(0,0,0,4)};
            button.FlatAppearance.BorderSize=0;button.Click+=(_,_)=>SelectCategory(index);categories.Add(button);sidebar.Controls.Add(button);
        }
        shell.Controls.Add(sidebar,0,0);
        var layout=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new(24),ColumnCount=1,RowCount=5,BackColor=Color.FromArgb(248,248,250)};
        layout.RowStyles.Add(new(SizeType.AutoSize));layout.RowStyles.Add(new(SizeType.AutoSize));layout.RowStyles.Add(new(SizeType.Percent,100));layout.RowStyles.Add(new(SizeType.AutoSize));layout.RowStyles.Add(new(SizeType.AutoSize));shell.Controls.Add(layout,1,0);
        layout.Controls.Add(pageTitle);
        Panel Card(string title,string description,Control control,Label? value,string? limits) {
            // Native TrackBar height changes with DPI. Auto-sized rows reserve
            // its actual preferred height instead of overlapping the labels below.
            var card=new TableLayoutPanel{AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink,ColumnCount=2,RowCount=3,BackColor=Color.White,Margin=new(0,0,0,16),Padding=new(18)};
            card.ColumnStyles.Add(new(SizeType.Percent,100));card.ColumnStyles.Add(new(SizeType.AutoSize));
            for(var i=0;i<3;i++)card.RowStyles.Add(new(SizeType.AutoSize));
            card.Controls.Add(new Label{Text=title,AutoSize=true,Font=new Font(Font.FontFamily,10,FontStyle.Bold),Margin=new(0,0,0,8)},0,0);
            if(value!=null){value.Anchor=AnchorStyles.Right;value.Margin=new(12,0,0,8);card.Controls.Add(value,1,0);}
            control.Dock=DockStyle.Top;control.Margin=new(0,0,0,8);card.Controls.Add(control,0,1);card.SetColumnSpan(control,2);
            var footer=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,ColumnCount=2,RowCount=1,Margin=Padding.Empty};
            footer.ColumnStyles.Add(new(SizeType.Percent,100));footer.ColumnStyles.Add(new(SizeType.AutoSize));
            var endpoints=limits?.Split(" — ");
            footer.Controls.Add(new Label{Text=endpoints?[0] ?? description,AutoSize=true,ForeColor=SystemColors.GrayText,Margin=Padding.Empty},0,0);
            if(endpoints is {Length:2})footer.Controls.Add(new Label{Text=endpoints[1],AutoSize=true,ForeColor=SystemColors.GrayText,Margin=Padding.Empty},1,0);
            card.Controls.Add(footer,0,2);card.SetColumnSpan(footer,2);
            general.Controls.Add(card);return card;
        }
        Card(d.T("鸟群数量","Bird count"),"",population,populationValue,"5 — 20");
        Card(d.T("全局尺寸","Global size"),"",globalSize,sizeValue,"1.0× — 2.0×");
        login.Text=d.T("随系统启动","Launch at Login");
        Card(d.T("启动","Startup"),d.T("登录电脑后自动启动啾啾。","Start ChirpOS automatically when you sign in."),login,null,null);
        general.ClientSizeChanged+=(_,_)=>{
            var width=Math.Max(200,general.ClientSize.Width-SystemInformation.VerticalScrollBarWidth-2);
            foreach(Control card in general.Controls){card.MinimumSize=new(width,0);card.MaximumSize=new(width,0);card.Width=width;}
        };
        population.ValueChanged+=(_,_)=>{if(refreshing)return;var copy=d.Clone();copy.Minimum=copy.Maximum=population.Value;d.Apply(copy);RefreshMode();};
        globalSize.ValueChanged+=(_,_)=>{if(refreshing)return;var copy=d.Clone();copy.Scale=globalSize.Value/100d;d.Apply(copy);RefreshMode();};
        login.Click+=(_,_)=>{d.ToggleLogin();RefreshMode();};tabs.Controls.Add(general);
        var header=new TableLayoutPanel{Dock=DockStyle.Fill,AutoSize=true,ColumnCount=2};
        header.ColumnStyles.Add(new(SizeType.Percent,100));header.ColumnStyles.Add(new(SizeType.Absolute,40));
        layout.Controls.Add(header);
        var unlock=new Label{Dock=DockStyle.Fill,MinimumSize=new(40,40)};
        long? lastDoubleClick=null;
        unlock.MouseDoubleClick+=(_,e)=>{
            if(e.Button!=MouseButtons.Left || pages.Count>2)return;
            var now=Environment.TickCount64;
            if(lastDoubleClick is {} previous && now-previous<=3000)EnableDebug();
            lastDoubleClick=now;
        };
        header.Controls.Add(unlock,1,0);
        header.Controls.Add(modeHint,0,0);
        layout.Controls.Add(tabs);
        var probabilities = new Panel { Dock=DockStyle.Fill,Padding = new(8) };
        var behavior = new Panel { Dock=DockStyle.Fill,Padding = new(8) };
        pages.AddRange([probabilities,behavior]);tabs.Controls.AddRange([probabilities,behavior]);
        var table = new TableLayoutPanel { Dock = DockStyle.Fill, AutoScroll = true, ColumnCount = 4, RowCount = d.Species.Length };
        table.ColumnStyles.Add(new(SizeType.Percent, 32)); table.ColumnStyles.Add(new(SizeType.Percent, 43));
        table.ColumnStyles.Add(new(SizeType.Absolute, 110)); table.ColumnStyles.Add(new(SizeType.Absolute, 80)); probabilities.Controls.Add(table);
        for (var i = 0; i < d.Species.Length; i++)
        {
            var index = i; table.RowStyles.Add(new(SizeType.Absolute, 49));
            table.Controls.Add(new Label { Text = d.Name(d.Species[i]), AutoSize = true, Anchor = AnchorStyles.Left }, 0, i);
            var slider = new TrackBar { Minimum = 0, Maximum = 10000, TickStyle = TickStyle.None, SmallChange = 10, LargeChange = 100, Dock = DockStyle.Fill };
            sliders.Add(slider); table.Controls.Add(slider, 1, i);
            var number = Number(0,100,0,2,.1m); values.Add(number); table.Controls.Add(number, 2, i);
            var locked = new CheckBox { Text = d.T("锁定", "Lock"), AutoSize = true, Anchor = AnchorStyles.Left };
            locks.Add(locked); table.Controls.Add(locked, 3, i);
            slider.ValueChanged += (_, _) => { if (!refreshing) { draft.Probability.Adjust(index, slider.Value); RefreshRows(); } };
            number.ValueChanged += (_, _) => { if (!refreshing) { draft.Probability.Adjust(index, (int)Math.Round(number.Value * 100)); RefreshRows(); } };
            locked.CheckedChanged += (_, _) => { if (!refreshing) { draft.Probability.Locked[index] = locked.Checked; RefreshRows(); } };
        }
        var detailLayout = new TableLayoutPanel { Dock=DockStyle.Fill,ColumnCount=1,RowCount=2 };
        detailLayout.RowStyles.Add(new(SizeType.AutoSize)); detailLayout.RowStyles.Add(new(SizeType.Percent,100)); behavior.Controls.Add(detailLayout);
        detailLayout.Controls.Add(new Label { AutoSize=true,MaximumSize=new(820,0),Text=d.T(
            "体长 8–110 cm · 振翅 0.5–7.5 次/秒 · 飞速 0.5–2×\n最短停留 2–300 秒 · 最长停留不超过 600 秒，且不能小于最短停留。",
            "Length 8–110 cm · Beats 0.5–7.5/sec · Speed 0.5–2×\nMinimum perch 2–300 sec · Maximum up to 600 sec, and no shorter than minimum.") });
        var detailTable = new TableLayoutPanel { Dock=DockStyle.Fill,AutoScroll=true,ColumnCount=6,RowCount=d.Species.Length+1 };
        detailTable.ColumnStyles.Add(new(SizeType.Percent,100));
        for(var j=0;j<5;j++) detailTable.ColumnStyles.Add(new(SizeType.Absolute,110));
        detailTable.RowStyles.Add(new(SizeType.Absolute,48));
        var headers=new[]{d.T("鸟种","Species"),d.T("体长 cm","Length cm"),d.T("振翅 次/秒","Beats / sec"),d.T("飞速 倍率","Speed ×"),d.T("最短停留 秒","Min perch s"),d.T("最长停留 秒","Max perch s")};
        for(var j=0;j<headers.Length;j++)detailTable.Controls.Add(new Label{Text=headers[j],AutoSize=true,Anchor=AnchorStyles.Left},j,0);
        for(var i=0;i<d.Species.Length;i++)
        {
            detailTable.RowStyles.Add(new(SizeType.Absolute,44));
            detailTable.Controls.Add(new Label{Text=d.Name(d.Species[i]),AutoSize=true,Anchor=AnchorStyles.Left},0,i+1);
            var s=draft.Resolve(d.Species[i]);
            var row=new[]{Number(8,110,(decimal)s.AdultLengthCM,2,.1m),Number(.5m,7.5m,(decimal)s.FlapFPS/8,3,.125m),Number(.5m,2,(decimal)s.Speed,2,.05m),Number(2,300,(decimal)s.PerchMin,1,1),Number(2,600,(decimal)s.PerchMax,1,1)};
            details.Add(row);for(var j=0;j<row.Length;j++)detailTable.Controls.Add(row[j],j+1,i+1);
        }
        detailLayout.Controls.Add(detailTable);
        var options = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, WrapContents = true }; layout.Controls.Add(options);
        total.AutoSize = true; total.Margin = new(3, 8, 20, 3); options.Controls.Add(total);
        var buttons = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Dock = DockStyle.Fill }; layout.Controls.Add(buttons);
        var save = new Button { Text = d.T("保存并应用", "Save & Apply"), AutoSize = true };
        saveButton=save;
        save.Click += (_, _) => {
            if(d.LifeList.Enabled)return;
            ValidateChildren();
            // Global menu settings may have changed while this draft was open.
            draft.Minimum=d.Settings.Minimum;draft.Maximum=d.Settings.Maximum;
            draft.Scale=d.Settings.Scale;draft.English=d.Settings.English;
            for(var i=0;i<details.Count;i++){
                var r=details[i];var b=new Behavior((double)r[0].Value,(double)r[1].Value*8,(double)r[2].Value,(double)r[3].Value,(double)r[4].Value);
                if(!b.Valid){SelectCategory(1);r[4].Focus();MessageBox.Show(d.Name(d.Species[i])+d.T("：最长停留不能小于最短停留。",": Maximum perch time must not be below minimum."));return;}
                draft.Behaviors[d.Species[i].Id]=b;
            }
            draft.PendingSpeciesIds=[];if(d.Apply(draft))Close();
        }; buttons.Controls.Add(save);
        var cancel=new Button{Text=d.T("关闭","Close"),AutoSize=true};cancel.Click+=(_,_)=>Close();buttons.Controls.Add(cancel);
        var reset=new Button{Text=d.T("恢复默认","Restore Defaults"),AutoSize=true};
        resetButton=reset;
        reset.Click+=(_,_)=>{
            if(d.LifeList.Enabled)return;
            draft.Probability=Probabilities.From(d.Species);RefreshRows();
            for(var i=0;i<details.Count;i++){var s=d.Species[i];var v=new[]{s.AdultLengthCM,s.FlapFPS/8,s.Speed,s.PerchMin,s.PerchMax};for(var j=0;j<5;j++)details[i][j].Value=(decimal)v[j];}
        };buttons.Controls.Add(reset);AcceptButton=save;CancelButton=cancel;RefreshRows();RefreshMode();
    }
    internal void RefreshMode() {
        refreshing=true;
        population.Value=Math.Clamp(desktop.Settings.Maximum,5,20);populationValue.Text=desktop.T($"{population.Value} 只",$"{population.Value} birds");
        globalSize.Value=Math.Clamp((int)Math.Round(desktop.Settings.Scale*100),100,200);sizeValue.Text=$"{globalSize.Value/100d:F2}×";login.Checked=Desktop.LoginEnabled();
        refreshing=false;
        var enabled=!desktop.LifeList.Enabled;
        foreach(var page in pages){page.Enabled=enabled;page.ForeColor=enabled?SystemColors.ControlText:SystemColors.GrayText;}
        saveButton.Enabled=resetButton.Enabled=enabled;
        saveButton.Visible=resetButton.Visible=selectedCategory>=0;total.Visible=selectedCategory==0;
        general.Visible=selectedCategory==-1;
        for(var i=0;i<pages.Count;i++)pages[i].Visible=selectedCategory==i;
        foreach(var button in categories)button.BackColor=(int)button.Tag! == selectedCategory ? Color.FromArgb(215,230,250):Color.FromArgb(238,240,243);
        pageTitle.Text=selectedCategory==-1?desktop.T("通用","General"):selectedCategory==0?desktop.T("鸟种概率","Probabilities"):selectedCategory==1?desktop.T("鸟种设置","Bird settings"):desktop.T("调试","Debug");
        modeHint.Text=selectedCategory==-1 ? desktop.T("调整桌面鸟群与显示偏好，更改即时生效。","Customize your flock and display. Changes apply immediately.") : enabled ? desktop.T("通用设置即时生效；以下鸟种设置需保存后生效。调整概率时，其他未锁定鸟种按比例变化，合计始终为 100%。","General settings apply immediately; save bird settings below to apply them. Unlocked probabilities redistribute to total 100%.") : desktop.T("观鸟模式下鸟种设置不生效。关闭观鸟模式后可修改。","Bird settings do not apply in birdwatching mode. Turn it off to edit them.");
    }
    void SelectCategory(int index){selectedCategory=index;RefreshMode();}
    void EnableDebug() {
        var page=new Panel{Dock=DockStyle.Fill,Padding=new(20)};
        var content=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=true};
        content.Controls.Add(new Label{AutoSize=true,MaximumSize=new(650,0),Text=desktop.T(
            "更新提示预览\n\n模拟更新会显示通知和图标红点。点击通知或菜单中的安装更新可查看确认框；选择安装后结束模拟，选择晚点再说则保留提示。不会下载、安装或重启。",
            "Update notification preview\n\nSimulate a ready update with a notification and icon badge. Click the notification or install menu item to review it. Confirm to end the simulation, or choose Later to keep the prompt. No download, installation or restart occurs.")});
        var simulate=new Button{Text=desktop.T("模拟有更新","Simulate update"),AutoSize=true,Margin=new(3,20,3,3)};
        var status=new Label{AutoSize=true,MaximumSize=new(650,0)};
        simulate.Click+=(_,_)=>status.Text=desktop.SimulateUpdate()?desktop.T("已显示模拟更新，可点击通知或菜单查看。","Simulated update ready; click the notification or menu to review."):desktop.T("更新器正在忙碌，请稍后重试。","The updater is busy; try again shortly.");
        content.Controls.Add(simulate);content.Controls.Add(status);page.Controls.Add(content);pages.Add(page);tabs.Controls.Add(page);SelectCategory(2);
    }
    internal void ScrollToSpecies(string id) {
        var i=Array.FindIndex(desktop.Species,s=>s.Id==id);if(i<0)return;
        SelectCategory(0);
        if(values[i].Parent is ScrollableControl sc)sc.ScrollControlIntoView(values[i]);
        values[i].Focus();
    }
    static NumericUpDown Number(decimal min,decimal max,decimal value,int decimals,decimal increment)=>new(){Minimum=min,Maximum=max,Value=value,DecimalPlaces=decimals,Increment=increment,Width=100,Anchor=AnchorStyles.Left,ThousandsSeparator=false};
    void RefreshRows()
    {
        refreshing=true;
        for(var i=0;i<sliders.Count;i++){sliders[i].Value=draft.Probability.Points[i];values[i].Value=draft.Probability.Points[i]/100m;locks[i].Checked=draft.Probability.Locked[i];sliders[i].Enabled=values[i].Enabled=draft.Probability.CanAdjust(i);}
        total.Text=desktop.T("合计：","Total: ")+(draft.Probability.Points.Sum()/100m).ToString("F2")+"%";refreshing=false;
    }
}
