using System;
using nkast.Aether.Physics2D.Common;
using nkast.Aether.Physics2D.Dynamics;
using nkast.Aether.Physics2D.Dynamics.Contacts;
using nkast.Aether.Physics2D.Collision;

// Interaction policy in design DIP. Aether owns integration, contacts and friction.
public sealed class GptGravityModel {
    public const double Gravity = 1800.0;
    public const double TapHeight = 24.0;
    public const double CompressionSeconds = 0.22;
    public const double ChargeSeconds = 1.2;
    public const double Restitution = 0.64;
    public double Height { get; private set; }
    public double Velocity { get; private set; }
    public double ScaleX { get; private set; }
    public double ScaleY { get; private set; }
    public double PeakHeight { get; private set; }
    public double Charge { get; private set; }
    public int Rebounds { get; private set; }
    public bool IsPressed { get; private set; }
    public bool ReleasePending { get; private set; }
    public bool Dragging { get; private set; }
    public bool Active { get { return IsPressed || ReleasePending || flying || impact > 0; } }
    public double GravityMultiplier { get; private set; }
    public double Elasticity { get; private set; }
    public double EffectiveGravity { get { return Gravity * GravityMultiplier; } }
    public double TapApex { get { return TapHeight * Elasticity; } }
    public void SetTuning(double gravity, double elasticity) {
        GravityMultiplier = double.IsNaN(gravity) || double.IsInfinity(gravity) ? 1.6 : Math.Max(0.5,Math.Min(4,gravity));
        Elasticity = double.IsNaN(elasticity) || double.IsInfinity(elasticity) ? 1 : Math.Max(0.25,Math.Min(3,elasticity));
        if(world != null) world.Gravity = new Vector2(0,(float)(-EffectiveGravity/Units));
    }
    const double Units = 100, FixedStep = 1.0 / 240;
    World world;
    Body body, bounds;
    Fixture floor;
    bool floorContact, stopLanding;
    double accumulator, ceilingLimit = -1, widthLimit = -1;
    public double HorizontalPosition { get; private set; }
    public double HorizontalVelocity { get { return body == null ? 0 : body.LinearVelocity.X * Units; } }
    public void SetHorizontalPosition(double x) {
        HorizontalPosition = Math.Max(0, x);
        if(Math.Abs(body.Position.X * Units - HorizontalPosition) > 0.5)
            body.Position = new Vector2((float)(HorizontalPosition / Units), body.Position.Y);
    }
    void CreateWorld() {
        bounds = null; floor = null; world = new World(new Vector2(0, (float)(-EffectiveGravity / Units)));
        body = world.CreateBody(Vector2.Zero, 0, BodyType.Dynamic);
        body.CreateCircle(0.25f, 1).Friction = 0.65f;
        body.FixedRotation = true; body.IsBullet = true;
        world.ContactManager.PreSolve += OnContact;
        ceilingLimit = widthLimit = -1;
    }
    void OnContact(Contact contact, ref Manifold manifold) {
        if (contact.FixtureA == floor || contact.FixtureB == floor) {
            floorContact = body.LinearVelocity.Y <= 0;
            stopLanding = !multiple || PeakHeight <= TapApex + 0.5;
            contact.Restitution = stopLanding ? 0 : (float)Restitution;
            contact.Friction = 0.65f;
        } else { contact.Restitution = 0.64f; contact.Friction = 0; }
    }
    void SetBounds(double ceiling, double width) {
        if (ceiling == ceilingLimit && width == widthLimit) return;
        if (bounds != null) world.Remove(bounds);
        bounds = world.CreateBody(Vector2.Zero, 0, BodyType.Static);
        float right = (float)(width / Units), top = (float)(ceiling / Units);
        floor = bounds.CreateEdge(new Vector2(-1,-0.25f), new Vector2(right+1,-0.25f));
        bounds.CreateEdge(new Vector2(-0.25f,-1),new Vector2(-0.25f,top+1));
        bounds.CreateEdge(new Vector2(right+0.25f,-1),new Vector2(right+0.25f,top+1));
        bounds.CreateEdge(new Vector2(-1,top+0.25f),new Vector2(right+1,top+0.25f));
        ceilingLimit=ceiling; widthLimit=width;
    }
    double age, held, impact, relax, releasedX, releasedY;
    bool flying, multiple;

    public GptGravityModel() { GravityMultiplier=1.6; Elasticity=1; Reset(); }
    public void Reset() {
        CreateWorld(); accumulator = 0;
        Height = Velocity = PeakHeight = Charge = age = held = impact = relax = 0;
        ScaleX = ScaleY = 1; Rebounds = 0;
        IsPressed = ReleasePending = Dragging = flying = multiple = false;
    }
    public void BeginPress() {
        IsPressed = true; ReleasePending = Dragging = flying = multiple = false;
        body.LinearVelocity = Vector2.Zero;
        Velocity = age = held = Charge = impact = relax = 0; Rebounds = 0; UpdatePose();
    }
    public void ReleasePress() {
        if (!IsPressed) return;
        IsPressed = false; ReleasePending = true;
        if (age >= CompressionSeconds - 1e-9) Launch();
    }
    public void BeginDrag() {
        IsPressed = ReleasePending = flying = false; Dragging = true;
        body.LinearVelocity = Vector2.Zero;
        Velocity = Charge = held = age = impact = relax = 0; ScaleX = ScaleY = 1;
    }
    public void DragTo(double height) { Height = Math.Max(0, height); }
    public void DropFrom(double height) {
        FlingFrom(height, 0, 0);
    }
    public void FlingFrom(double height, double vx, double vy) {
        double x = HorizontalPosition;
        Reset(); SetHorizontalPosition(x); Height = Math.Max(0, height);
        vx = Math.Max(-1600, Math.Min(1600, vx));
        vy = Math.Max(-1600, Math.Min(1600, vy));
        body.Position = new Vector2((float)(x/Units), (float)(Height/Units));
        body.LinearVelocity = new Vector2((float)(vx/Units),(float)(vy/Units));
        Velocity = vy; PeakHeight = Height + Math.Max(0,vy)*Math.Max(0,vy)/(2*EffectiveGravity);
        multiple = true; flying = Height > 0 || vx != 0 || vy != 0;
    }
    public void CancelPress() { DropFrom(Height); }
    void Launch() {
        releasedX = ScaleX; releasedY = ScaleY; relax = 0.1;
        Charge = Math.Max(0, Math.Min(1, (held - CompressionSeconds) / ChargeSeconds));
        double jump = Elasticity * (TapHeight + 260 * Charge * Charge);
        Velocity = Math.Sqrt(2 * EffectiveGravity * jump);
        body.Position = new Vector2((float)(HorizontalPosition/Units),(float)(Height/Units));
        body.LinearVelocity = new Vector2(0,(float)((Velocity+EffectiveGravity*FixedStep/2)/Units));
        PeakHeight = Height + jump; multiple = Charge > 1e-8;
        flying = true; ReleasePending = false; UpdatePose();
    }
    public void Advance(double seconds, double maximumHeight) { Advance(seconds,maximumHeight,10000); }
    public void Advance(double seconds, double maximumHeight, double maximumWidth) {
        if (double.IsNaN(seconds) || double.IsInfinity(seconds) || seconds <= 0) return;
        maximumHeight = double.IsNaN(maximumHeight) ? 0 : Math.Max(0, maximumHeight);
        if (maximumHeight <= 0) { Reset(); return; }
        if (Height > maximumHeight) { Height = maximumHeight; Velocity = Math.Min(0, Velocity); }
        PeakHeight = Math.Min(PeakHeight, maximumHeight);
        maximumWidth = Math.Max(0, maximumWidth);
        SetBounds(maximumHeight, maximumWidth);
        // Preserve the solver's cached contacts: do not teleport the body each rendered frame.
        if(body.Position.X < 0 || body.Position.X * Units > maximumWidth || body.Position.Y * Units > maximumHeight)
            body.Position = new Vector2((float)(Math.Min(maximumWidth,Math.Max(0,HorizontalPosition))/Units),(float)(Height/Units));
        // Pause rather than fast-forward across a hidden/busy UI interval.
        accumulator += Math.Min(seconds, 0.1);
        double remaining = accumulator;
        while (remaining >= FixedStep - 1e-9) {
            double dt = FixedStep;
            if (ReleasePending && age < CompressionSeconds)
                dt = Math.Min(dt, CompressionSeconds - age);
            remaining -= dt;
            impact = Math.Max(0, impact - dt);
            relax = Math.Max(0, relax - dt);
            if (IsPressed || ReleasePending) {
                age += dt;
                if (IsPressed) held += dt;
                Charge = Math.Max(0, Math.Min(1, (held - CompressionSeconds) / ChargeSeconds));
                if (ReleasePending && age >= CompressionSeconds - 1e-9) Launch();
            } else if (flying) AdvanceFlight(dt, maximumHeight);
        }
        accumulator = remaining;
        UpdatePose();
    }
    void AdvanceFlight(double seconds, double ceiling) {
        double previousVelocity = Velocity;
        floorContact = false; stopLanding = false;
        world.Step((float)seconds);
        Height = Math.Max(0, Math.Min(ceiling, body.Position.Y * Units));
        HorizontalPosition = Math.Max(0,Math.Min(widthLimit,body.Position.X * Units));
        Velocity = body.LinearVelocity.Y * Units;
        if (floorContact && previousVelocity <= 0) {
            impact = 0.12;
            if (stopLanding) {
                Height = Velocity = 0;
                body.Position = new Vector2(body.Position.X,0);
                body.LinearVelocity = new Vector2(body.LinearVelocity.X,0);
            } else if (Velocity > 0) {
                PeakHeight = Height + Velocity*Velocity/(2*EffectiveGravity); Rebounds++;
            }
        }
        if (Height < 0.8 && Math.Abs(Velocity) < 2 && Math.Abs(HorizontalVelocity) < 2) {
            Height = Velocity = 0; body.LinearVelocity = Vector2.Zero;
            body.Position = new Vector2(body.Position.X,0); flying = false;
        }
    }
    void UpdatePose() {
        if (IsPressed || ReleasePending) {
            double t = Math.Min(1, age / CompressionSeconds);
            double ease = t * t * (3 - 2 * t);
            ScaleY = 1 - 0.12 * ease - 0.4 * Charge;
            ScaleX = 1 + 0.05 * ease + 0.4 * Charge;
        } else {
            double stretch = flying ? Math.Min(0.06, Math.Abs(Velocity) / 14000) : 0;
            double pulse = impact > 0 ? Math.Sin(Math.PI * (1 - impact / 0.12)) : 0;
            ScaleX = 1 - stretch * 0.5 + pulse * 0.08;
            ScaleY = 1 + stretch - pulse * 0.15;
            if (relax > 0) {
                double blend = relax / 0.1;
                blend = blend * blend * (3 - 2 * blend);
                ScaleX += (releasedX - ScaleX) * blend;
                ScaleY += (releasedY - ScaleY) * blend;
            }
        }
    }
}

// Native pointer sampling runs independently of the WPF dispatcher. No private data is stored.
public sealed class GptDragVelocity : IDisposable {
    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    struct Point { public int X,Y; }
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool GetCursorPos(out Point p);
    struct Sample { public double Time,X,Y; }
    readonly object gate = new object();
    readonly System.Collections.Generic.List<Sample> samples = new System.Collections.Generic.List<Sample>();
    readonly System.Diagnostics.Stopwatch clock = new System.Diagnostics.Stopwatch();
    System.Threading.Timer timer;
    double lastMotion;
    bool running;
    public void Record(double time,double x,double y) {
        lock(gate) {
            if(samples.Count==0 || samples[samples.Count-1].X!=x || samples[samples.Count-1].Y!=y)lastMotion=time;
            samples.Add(new Sample{Time=time,X=x,Y=y});
            while(samples.Count>1 && samples[0].Time < time-0.10)samples.RemoveAt(0);
        }
    }
    void Poll(object state) { lock(gate) { if(!running)return; Point p;if(GetCursorPos(out p))Record(clock.Elapsed.TotalSeconds,p.X,p.Y); } }
    public void Start() {
        Stop();lock(gate){samples.Clear();lastMotion=0;clock.Restart();running=true;Poll(null);timer=new System.Threading.Timer(Poll,null,8,8);}
    }
    public double[] ReleaseAt(double time,double x,double y,double unit) {
        lock(gate) {
            Record(time,x,y);
            if(time-lastMotion>=0.08 || samples.Count<2 || unit<=0)return new double[2];
            Sample first=samples[0],last=samples[samples.Count-1];double dt=last.Time-first.Time;
            if(dt<0.008)return new double[2];
            double vx=(last.X-first.X)/dt/unit,vy=(first.Y-last.Y)/dt/unit;
            if(vx*vx+vy*vy<35*35)return new double[2];
            return new[]{vx,vy};
        }
    }
    public double[] Finish(double unit) {
        lock(gate){Point p;double[] v=GetCursorPos(out p)?ReleaseAt(clock.Elapsed.TotalSeconds,p.X,p.Y,unit):new double[2];Stop();return v;}
    }
    public void Stop(){lock(gate){running=false;if(timer!=null){timer.Dispose();timer=null;}}}
    public void Dispose(){Stop();}
}
