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
        body.Position = new Vector2((float)(HorizontalPosition / Units), body.Position.Y);
    }
    void CreateWorld() {
        bounds = null; floor = null; world = new World(new Vector2(0, (float)(-Gravity / Units)));
        body = world.CreateBody(Vector2.Zero, 0, BodyType.Dynamic);
        body.CreateCircle(0.25f, 1).Friction = 0.65f;
        body.FixedRotation = true; body.IsBullet = true;
        world.ContactManager.PreSolve += OnContact;
        ceilingLimit = widthLimit = -1;
    }
    void OnContact(Contact contact, ref Manifold manifold) {
        if (contact.FixtureA == floor || contact.FixtureB == floor) {
            floorContact = body.LinearVelocity.Y <= 0;
            stopLanding = !multiple || PeakHeight <= TapHeight + 0.5;
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

    public GptGravityModel() { Reset(); }
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
        Velocity = vy; PeakHeight = Height + Math.Max(0,vy)*Math.Max(0,vy)/(2*Gravity);
        multiple = true; flying = Height > 0 || vx != 0 || vy != 0;
    }
    public void CancelPress() { DropFrom(Height); }
    void Launch() {
        releasedX = ScaleX; releasedY = ScaleY; relax = 0.1;
        Charge = Math.Max(0, Math.Min(1, (held - CompressionSeconds) / ChargeSeconds));
        double jump = TapHeight + 260 * Charge * Charge;
        Velocity = Math.Sqrt(2 * Gravity * jump);
        body.Position = new Vector2((float)(HorizontalPosition/Units),(float)(Height/Units));
        body.LinearVelocity = new Vector2(0,(float)((Velocity+Gravity*FixedStep/2)/Units));
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
        body.Position = new Vector2((float)(Math.Min(maximumWidth,HorizontalPosition)/Units),(float)(Height/Units));
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
                PeakHeight = Height + Velocity*Velocity/(2*Gravity); Rebounds++;
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
