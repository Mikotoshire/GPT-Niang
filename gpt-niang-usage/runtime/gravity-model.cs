using System;
using nkast.Aether.Physics2D.Common;
using nkast.Aether.Physics2D.Dynamics;
using nkast.Aether.Physics2D.Dynamics.Contacts;
using nkast.Aether.Physics2D.Collision;

// Interaction policy in design DIP. Aether owns integration and contacts.
public sealed class GptGravityModel {
    public const double Gravity = 1800.0;
    public const double TapHeight = 24.0;
    public const double CompressionSeconds = 0.22;
    public const double ChargeSeconds = 1.2;
    public const double Restitution = 0.64;
    // Unit-mass energy proxy and artistic spring stiffness, not real-world material units.
    public const double SpringStiffness = 4000000;
    public double ImpactEnergy { get; private set; }
    public double StoredElasticEnergy { get; private set; }
    public double SpringCompression { get; private set; }
    public double SpringForce { get { return SpringStiffness * SpringCompression; } }
    // Chosen personal defaults; saved valid preferences take precedence.
    public const double DefaultGravityMultiplier = 1.4, DefaultElasticity = 2.5;
    public const double DefaultTapCompression = 2, DefaultImpactSquish = 1.5;
    public const double DefaultAnimationSpeed = 1, DefaultCompressionCurve = 1.5;
    public const double DefaultGroundFrictionMultiplier = 0.2, DefaultReboundStrength = 65;
    public const double DefaultEnergyConversion = 0.85 * DefaultReboundStrength;
    public double EnergyConversion { get; private set; }
    public double EnergyRetention { get { return EnergyConversion / 100; } }
    public void SetEnergyConversion(double percent) {
        EnergyConversion = double.IsNaN(percent) || double.IsInfinity(percent) ? DefaultEnergyConversion : Math.Max(0, Math.Min(85, percent));
    }
    double visualDepth, impactFrictionBoost;
    void UpdateImpactDepth() {
        double amount = ImpactSquish * SpringCompression;
        visualDepth = 0.72 * amount / (0.30 + amount);
    }
    bool bounceAfterCompression;
    void ClearSpring() {
        ImpactEnergy = StoredElasticEnergy = SpringCompression = visualDepth = impactFrictionBoost = 0;
        bounceAfterCompression = false;
    }
    public const double HorizontalRetention = 0.82;
    public const float GroundFriction = 0.18f;
    public double GroundFrictionMultiplier { get; private set; }
    public void SetGroundFriction(double value) {
        GroundFrictionMultiplier = double.IsNaN(value) || double.IsInfinity(value) ? DefaultGroundFrictionMultiplier : Math.Max(0, Math.Min(3, value));
    }
    public int FloorImpacts { get; private set; }
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
    // AI-generated maintenance, insufficiently validated; see AI-NOTICE.md.
    public double TapCompression { get; private set; }
    public void SetTapCompression(double value) {
        TapCompression = double.IsNaN(value) || double.IsInfinity(value) ? DefaultTapCompression : Math.Max(0, Math.Min(3, value));
        UpdatePose();
    }
    public double CompressionCurve { get; private set; }
    double landingCurve;
    public void SetCompressionCurve(double value) {
        CompressionCurve = double.IsNaN(value) || double.IsInfinity(value) ? DefaultCompressionCurve : Math.Max(1.5, Math.Min(3, value));
    }
    public double GetCompressionProgress(double time) { return CompressionProgress(time, CompressionCurve); }
    static double CompressionProgress(double t, double slope) {
        if (double.IsNaN(t) || t <= 0) return 0;
        if (t >= 1) return 1;
        // Cubic Hermite: start slope 1.5..3, end slope zero; always decelerating.
        return t * (slope + t * (3 - 2 * slope + t * (slope - 2)));
    }
    public double AnimationSpeed { get; private set; }
    public void SetAnimationSpeed(double value) {
        AnimationSpeed = double.IsNaN(value) || double.IsInfinity(value) ? DefaultAnimationSpeed : Math.Max(0.25, Math.Min(3, value));
    }
    public double ImpactSquish { get; private set; }
    public void SetImpactSquish(double value) {
        ImpactSquish = double.IsNaN(value) || double.IsInfinity(value) ? DefaultImpactSquish : Math.Max(0, Math.Min(3, value));
        UpdateImpactDepth(); UpdatePose();
    }
    public double EffectiveGravity { get { return Gravity * GravityMultiplier; } }
    public double TapApex { get { return TapHeight * Elasticity; } }
    public void SetTuning(double gravity, double elasticity) {
        GravityMultiplier = double.IsNaN(gravity) || double.IsInfinity(gravity) ? DefaultGravityMultiplier : Math.Max(0.5,Math.Min(4,gravity));
        Elasticity = double.IsNaN(elasticity) || double.IsInfinity(elasticity) ? DefaultElasticity : Math.Max(0.25,Math.Min(3,elasticity));
        if(world != null) world.Gravity = new Vector2(0,(float)(-EffectiveGravity/Units));
    }
    const double Units = 100, FixedStep = 1.0 / 240;
    World world;
    Body body, bounds;
    Fixture floor;
    bool floorContact, stopLanding, touchingFloor, wasTouchingFloor;
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
        body.CreateCircle(0.25f, 1).Friction = GroundFriction;
        body.FixedRotation = true; body.IsBullet = true;
        world.ContactManager.PreSolve += OnContact;
        ceilingLimit = widthLimit = -1;
    }
    void OnContact(Contact contact, ref Manifold manifold) {
        if(!contact.IsTouching)return;
        if (contact.FixtureA == floor || contact.FixtureB == floor) {
            touchingFloor = true;
            if (landing) {
                floorContact = false;
                contact.Restitution = 0; contact.Friction = 0;
                return;
            }
            floorContact = body.LinearVelocity.Y <= 0;
            stopLanding = !multiple || PeakHeight <= TapApex + 0.5;
            // The spring reservoir releases the rebound after visual recovery.
            contact.Restitution = 0;
            // Do not let a large vertical impact impulse erase all tangential momentum.
            // Ground drag below is explicit so floor holds cannot disrupt solver friction.
            contact.Friction = 0;
        } else { contact.Restitution = 0.64f; contact.Friction = 0; }
    }
    void SetBounds(double ceiling, double width) {
        if (ceiling == ceilingLimit && width == widthLimit) return;
        if (bounds != null) world.Remove(bounds);
        bounds = world.CreateBody(Vector2.Zero, 0, BodyType.Static);
        float right = (float)(width / Units), top = (float)(ceiling / Units);
        floor = bounds.CreateEdge(new Vector2(-1,-0.25f), new Vector2(right+1,-0.25f));
        floor.Shape.Radius = 0; // The circle already defines the exact visible-foot boundary.
        bounds.CreateEdge(new Vector2(-0.25f,-1),new Vector2(-0.25f,top+1));
        bounds.CreateEdge(new Vector2(right+0.25f,-1),new Vector2(right+0.25f,top+1));
        bounds.CreateEdge(new Vector2(-1,top+0.25f),new Vector2(right+1,top+0.25f));
        ceilingLimit=ceiling; widthLimit=width;
    }
    const double LandingCompressionShare = 0.4142135623730951, TakeoffStretchSeconds = 0.08;
    const double MinLandingSeconds = 0.06, MaxLandingSeconds = 0.30, DurationCompressionReference = 0.25;
    double age, held, impact, impactSpeed, impactDuration, relax, releasedX, releasedY;
    double landingEntryX, landingEntryY, takeoffStretch;
    bool flying, multiple, landing, grounded;

    public GptGravityModel() { GroundFrictionMultiplier=DefaultGroundFrictionMultiplier; GravityMultiplier=DefaultGravityMultiplier; Elasticity=DefaultElasticity; ImpactSquish=DefaultImpactSquish; AnimationSpeed=DefaultAnimationSpeed; TapCompression=DefaultTapCompression; EnergyConversion=DefaultEnergyConversion; CompressionCurve=DefaultCompressionCurve; Reset(); }
    public void Reset() {
        CreateWorld(); accumulator = 0; FloorImpacts = 0; wasTouchingFloor = touchingFloor = false;
        Height = Velocity = PeakHeight = Charge = age = held = impact = relax = 0;
        impactSpeed = impactDuration = 0; ClearSpring(); landing = false;
        landingEntryX = landingEntryY = takeoffStretch = 0;
        ScaleX = ScaleY = 1; Rebounds = 0;
        IsPressed = ReleasePending = Dragging = flying = multiple = grounded = false;
    }
    public void BeginPress() {
        IsPressed = true; ReleasePending = Dragging = flying = multiple = false;
        body.LinearVelocity = Vector2.Zero;
        Velocity = age = held = Charge = impact = relax = 0; Rebounds = 0;
        ClearSpring(); takeoffStretch = 0; landing = grounded = false;
        UpdatePose();
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
        ClearSpring(); takeoffStretch = 0; landing = grounded = false;
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
        // The stopping threshold must include downward fling energy as well.
        Velocity = vy; PeakHeight = Height + vy*vy/(2*EffectiveGravity);
        grounded = Height == 0 && vy == 0;
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
            impact = Math.Max(0, impact - dt * AnimationSpeed);
            relax = Math.Max(0, relax - dt * AnimationSpeed);
            takeoffStretch = Math.Max(0, takeoffStretch - dt * AnimationSpeed);
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
        double previousVelocity = Velocity, previousHeight = Height;
        // Repair exact resting support only; never snap a falling body near the floor.
        if (!grounded && !landing && previousHeight == 0 && previousVelocity == 0) grounded = true;
        floorContact = touchingFloor = false; stopLanding = false;
        world.Step((float)seconds);
        Height = Math.Max(0, Math.Min(ceiling, body.Position.Y * Units));
        HorizontalPosition = Math.Max(0,Math.Min(widthLimit,body.Position.X * Units));
        Velocity = body.LinearVelocity.Y * Units;
        // AI-generated maintenance; insufficiently validated. See AI-NOTICE.md.
        // Apply mu*g only during supported sliding/landing, not the first impact
        // or airborne motion. Explicit drag stays stable while HoldOnFloor pins Y.
        if (grounded || landing) {
            double vx = body.LinearVelocity.X;
            // Downward impact speed is a cheap pressure proxy, not a force solver.
            // Fade the cached boost during floor deformation, then use normal drag.
            double pressure = landing && impactDuration > 0 ? 1 + impactFrictionBoost * impact / impactDuration : 1;
            double speed = Math.Max(0, Math.Abs(vx) - GroundFriction * GroundFrictionMultiplier * pressure * EffectiveGravity * seconds / Units);
            body.LinearVelocity = new Vector2((float)(Math.Sign(vx) * speed), body.LinearVelocity.Y);
        }
        if (grounded && !landing) HoldOnFloor();
        else if (landing) {
            HoldOnFloor();
            if (impact <= 0) {
                landing = false;
                // Convert the retained spring energy once, after visual recovery.
                if (bounceAfterCompression && StoredElasticEnergy > 0) {
                    grounded = false;
                    Velocity = Math.Sqrt(2 * Math.Min(StoredElasticEnergy, EffectiveGravity * ceiling));
                    body.LinearVelocity = new Vector2(body.LinearVelocity.X, (float)(Velocity / Units));
                    PeakHeight = Velocity * Velocity / (2 * EffectiveGravity); Rebounds++;
                    takeoffStretch = TakeoffStretchSeconds;
                }
                StoredElasticEnergy = SpringCompression = visualDepth = 0; bounceAfterCompression = false;
                impactFrictionBoost = 0;
            }
        }
        else if (floorContact && previousVelocity <= 0) {
            if(!wasTouchingFloor && (previousHeight>0 || previousVelocity<0)){
                body.LinearVelocity = new Vector2(body.LinearVelocity.X * (float)HorizontalRetention,body.LinearVelocity.Y);
                FloorImpacts++;
                landingCurve = CompressionCurve;
                impactSpeed = Math.Max(0, -previousVelocity);
                impactFrictionBoost = Math.Min(2, impactSpeed / 600);
                ImpactEnergy = 0.5 * impactSpeed * impactSpeed;
                StoredElasticEnergy = ImpactEnergy * EnergyRetention;
                SpringCompression = Math.Sqrt(2 * StoredElasticEnergy / SpringStiffness);
                UpdateImpactDepth();
                double incomingStretch = FlightStretch(previousVelocity);
                landingEntryX = -incomingStretch * 0.5; landingEntryY = incomingStretch;
                if (relax > 0) {
                    double blend = SmoothStep(relax / 0.1);
                    landingEntryX += (releasedX - 1 - landingEntryX) * blend;
                    landingEntryY += (releasedY - 1 - landingEntryY) * blend;
                }
                // Artistic contact timing: weaker stored energy recovers sooner, without a spring solver.
                impactDuration = MinLandingSeconds + (MaxLandingSeconds - MinLandingSeconds) * SpringCompression / (DurationCompressionReference + SpringCompression);
                impact = impactDuration; relax = 0;
                takeoffStretch = 0;
                bounceAfterCompression = !stopLanding;
                landing = true;
                grounded = true;
                HoldOnFloor();
            }
            else if (stopLanding) HoldOnFloor();
        }
        wasTouchingFloor = touchingFloor;
        if (!landing && Height < 0.8 && Math.Abs(Velocity) < 2 && Math.Abs(HorizontalVelocity) < 2) {
            Height = Velocity = 0; body.LinearVelocity = Vector2.Zero;
            body.Position = new Vector2(body.Position.X,0); flying = false;
        }
    }
    void HoldOnFloor() {
        // AI-generated maintenance; insufficiently validated. See AI-NOTICE.md.
        // Confirmed floor support also restores drag after a lost support latch.
        grounded = true;
        Height = Velocity = 0;
        body.Position = new Vector2(body.Position.X, 0);
        body.LinearVelocity = new Vector2(body.LinearVelocity.X, 0);
    }
    static double SmoothStep(double value) {
        value = Math.Max(0, Math.Min(1, value));
        return value * value * (3 - 2 * value);
    }
    double FlightStretch(double velocity) {
        double stretch = Math.Min(0.06, Math.Abs(velocity) / 14000);
        return takeoffStretch > 0 ? stretch * SmoothStep(1 - takeoffStretch / TakeoffStretchSeconds) : stretch;
    }
    void UpdatePose() {
        if (IsPressed || ReleasePending) {
            double t = Math.Min(1, age / CompressionSeconds);
            double ease = t * t * (3 - 2 * t);
            ScaleY = 1 - 0.12 * TapCompression * ease - 0.4 * Charge;
            ScaleX = 1 + 0.05 * TapCompression * ease + 0.4 * Charge;
        } else {
            double stretch = flying ? FlightStretch(Velocity) : 0;
            ScaleX = 1 - stretch * 0.5; ScaleY = 1 + stretch;
            if (landing) {
                double phase = Math.Max(0, Math.Min(1, 1 - impact / impactDuration));
                // Compression decelerates into the peak. Longer recovery starts
                // from rest, accelerates, then brakes before reaching neutral.
                double compression = CompressionProgress(phase / LandingCompressionShare, landingCurve);
                double envelope = phase <= LandingCompressionShare
                    ? compression
                    : 0.5 * (1 + Math.Cos(Math.PI * (phase - LandingCompressionShare) / (1 - LandingCompressionShare)));
                // Cached spring compression drives both force and the visual envelope.
                // Q is an appearance multiplier; visual saturation does not add energy.
                double pulse = visualDepth * envelope;
                double entryFade = 1 - compression;
                ScaleX = 1 + landingEntryX * entryFade + pulse * (0.08 / 0.15);
                ScaleY = 1 + landingEntryY * entryFade - pulse;
            }
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
