using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Media;

// Configuration is refreshed by PowerShell at input/layout boundaries, never per frame.
public sealed class GptGravityScene {
    public GptGravityModel Model;
    public ScaleTransform Scale;
    public IntPtr Widget, Host;
    public bool Follow, Free;
    public int Width, Height, FrameLeft, FrameTop, FrameRight, FrameBottom;
    public double Unit, Padding, Dpi, Left, Right;
    public string Anchor;
    public Func<int[]> ReadFrame;
    public Action<int,int,int,string> Move;
    public bool HasPose;
    public double PoseLeft, PoseRight;
    public int X,Y;
}

// Model, image pose and native movement stay in C#. Script notifications are limited to 4 Hz.
public sealed class GptGravityRenderLoop {
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left,Top,Right,Bottom; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out Rect r);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int height,uint flags);
    public bool IsEnabled { get; private set; }
    public GptGravityScene Scene { get; set; }
    public event EventHandler Tick;
    public int TargetFps { get { return 90; } }
    public long FrameCount { get; private set; }
    public long SlowFrames { get; private set; }
    public double Fps { get { double span=(last-first).TotalSeconds;return span>0?(FrameCount-1)/span:0; } }
    public long PositionUpdates { get; private set; }
    public double TotalStepMs { get; private set; }
    public double MeanStepMs { get { return FrameCount>0?TotalStepMs/FrameCount:0; } }
    public double MaxStepMs { get; private set; }
    // AI-generated maintenance diagnostics: numeric timings only, see AI-NOTICE.md.
    public double MeanPhysicsMs { get { return MeanMilliseconds(physicsTicks); } }
    public double MeanPoseMs { get { return MeanMilliseconds(poseTicks); } }
    public double MeanPlacementMs { get { return MeanMilliseconds(placementTicks); } }
    long physicsTicks,poseTicks,placementTicks;
    double MeanMilliseconds(long ticks) { return FrameCount>0?1000.0*ticks/Stopwatch.Frequency/FrameCount:0; }
    public string LastError { get; private set; }
    TimeSpan last = TimeSpan.MinValue, first;
    readonly Stopwatch clock=new Stopwatch(), cost=new Stopwatch();
    double previous, notified, nextFrame;
    bool rendering;
    public void Start() {
        if(IsEnabled)return;IsEnabled=true;last=TimeSpan.MinValue;FrameCount=SlowFrames=0;MaxStepMs=TotalStepMs=0;PositionUpdates=0;LastError=null;
        physicsTicks=poseTicks=placementTicks=0;
        previous=notified=nextFrame=0;clock.Restart();CompositionTarget.Rendering+=Render;
    }
    public void Stop() { if(!IsEnabled)return;IsEnabled=false;CompositionTarget.Rendering-=Render; }
    void Notify(){var handler=Tick;if(handler!=null)handler(this,EventArgs.Empty);}
    bool Step(double seconds) {
        var s=Scene;
        if(!IsWindowVisible(s.Widget) || (s.Follow && (s.Host==IntPtr.Zero || !IsWindowVisible(s.Host) || IsIconic(s.Host))))return false;
        int[] frame=s.ReadFrame==null?null:s.ReadFrame();
        if(frame!=null){s.FrameLeft=frame[0];s.FrameTop=frame[1];s.FrameRight=frame[2];s.FrameBottom=frame[3];}
        if(s.Unit<=0 || s.FrameRight<=s.FrameLeft || s.FrameBottom<=s.FrameTop)return false;
        double ceiling=Math.Max(0,(s.FrameBottom-s.FrameTop-s.Height+s.Padding)/s.Unit);
        double width=Math.Max(0,(s.FrameRight-s.FrameLeft-s.Width)/s.Unit);
        long started=Stopwatch.GetTimestamp();
        s.Model.Advance(seconds,ceiling,width);
        physicsTicks+=Stopwatch.GetTimestamp()-started;started=Stopwatch.GetTimestamp();
        s.Scale.ScaleX=s.Model.ScaleX;s.Scale.ScaleY=s.Model.ScaleY;
        poseTicks+=Stopwatch.GetTimestamp()-started;started=Stopwatch.GetTimestamp();
        int x=s.Free?(int)Math.Round(s.FrameLeft+s.Model.HorizontalPosition*s.Unit):
            s.Anchor=="right"?(int)Math.Round(s.FrameRight-s.Width-s.Right*s.Dpi):(int)Math.Round(s.FrameLeft+s.Left*s.Dpi);
        x=Math.Max(s.FrameLeft,Math.Min(s.FrameRight-s.Width,x));
        int bottom=(int)Math.Round(s.Model.Height*s.Unit-s.Padding);
        int y=(int)Math.Round(s.FrameBottom-s.Height+s.Padding-s.Model.Height*s.Unit);
        string anchor=s.Free?"free":s.Anchor;
        double left=(x-s.FrameLeft)/s.Dpi,right=(s.FrameRight-x-s.Width)/s.Dpi;
        if(s.Move!=null)s.Move((int)Math.Round(left*s.Dpi),(int)Math.Round(right*s.Dpi),bottom,anchor);
        else {
            Rect old;if(!GetWindowRect(s.Widget,out old) || old.Left!=x || old.Top!=y)
                if(!SetWindowPos(s.Widget,IntPtr.Zero,x,y,0,0,0x15))throw new InvalidOperationException("Native animation movement failed");
        }
        if(!s.HasPose || s.X!=x || s.Y!=y)PositionUpdates++;
        s.X=x;s.Y=y;s.PoseLeft=left;s.PoseRight=right;s.HasPose=true;
        placementTicks+=Stopwatch.GetTimestamp()-started;
        return s.Model.Active;
    }
    void Render(object sender,EventArgs args) {
        if(rendering)return;
        rendering=true;try{RenderFrame(sender,args);}finally{rendering=false;}
    }
    void RenderFrame(object sender,EventArgs args) {
        var frame=args as RenderingEventArgs;
        if(frame!=null){if(frame.RenderingTime==last)return;last=frame.RenderingTime;}
        double now=clock.Elapsed.TotalSeconds;
        // Rendering can fire faster than scan-out. Keep a phase-based 90-Hz animation budget (headroom above the 60-Hz minimum)
        // instead of moving the layered HWND hundreds of times per second.
        if(Scene!=null){
            if(now+0.0001<nextFrame)return;
            nextFrame+=1.0/TargetFps;
            if(nextFrame<now-1.0/TargetFps)nextFrame=now+1.0/TargetFps;
        }
        if(FrameCount==0)first=last;
        FrameCount++;
        double dt=now-previous;previous=now;
        if(dt>1.0/40)SlowFrames++;
        if(Scene==null){Notify();return;}
        cost.Restart();bool active;
        try{active=Step(dt);}catch(Exception e){LastError=e.ToString();active=false;}
        cost.Stop();TotalStepMs+=cost.Elapsed.TotalMilliseconds;MaxStepMs=Math.Max(MaxStepMs,cost.Elapsed.TotalMilliseconds);
        if(!active){Stop();Notify();}
        else if(now-notified>=0.25){notified=now;Notify();}
    }
}
