using GTA;
using GTA.Native;
using System;
using System.Collections.Generic;

// GTA-NG first playable prototype.
// This tunes a small set of GTA compact cars while retaining GTA's car models.
// It is a bridge build until a BeamNG model conversion and data pipeline exist.
public sealed class GtaNgPrototype : Script
{
    private const int TickIntervalMs = 100;
    private const float CrashDeltaSpeedMetersPerSecond = 7.0f;
    private const float MinimumImpactSpeedMetersPerSecond = 8.5f;

    private readonly HashSet<int> _supportedModels = new HashSet<int>
    {
        Joaat("blista"),
        Joaat("prairie"),
        Joaat("issi2"),
        Joaat("panto"),
        Joaat("dilettante"),
        Joaat("kanjo")
    };

    private int _trackedVehicleHandle;
    private float _previousSpeed;
    private bool _previouslyColliding;

    public GtaNgPrototype()
    {
        Interval = TickIntervalMs;
        Tick += OnTick;
    }

    private void OnTick(object sender, EventArgs e)
    {
        Vehicle vehicle = Game.Player.Character.CurrentVehicle;
        if (vehicle == null || !vehicle.Exists() || !_supportedModels.Contains(vehicle.Model.Hash))
        {
            ResetTrackedVehicle();
            return;
        }

        if (vehicle.Handle != _trackedVehicleHandle)
        {
            _trackedVehicleHandle = vehicle.Handle;
            _previousSpeed = Function.Call<float>(Hash.GET_ENTITY_SPEED, vehicle.Handle);
            _previouslyColliding = false;
            ApplyDrivingTune(vehicle);
            GTA.UI.Screen.ShowSubtitle("~b~GTA-NG~s~ test handling active — compact car prototype", 4500);
        }

        float speed = Function.Call<float>(Hash.GET_ENTITY_SPEED, vehicle.Handle);
        bool colliding = Function.Call<bool>(Hash.HAS_ENTITY_COLLIDED_WITH_ANYTHING, vehicle.Handle);
        float speedLoss = _previousSpeed - speed;

        if (colliding && !_previouslyColliding &&
            speedLoss >= CrashDeltaSpeedMetersPerSecond &&
            _previousSpeed >= MinimumImpactSpeedMetersPerSecond)
        {
            ApplyCrashDamage(vehicle, speedLoss);
        }

        _previousSpeed = speed;
        _previouslyColliding = colliding;
    }

    private static void ApplyDrivingTune(Vehicle vehicle)
    {
        // GTA exposes power and grip modifiers to scripts, but not BeamNG's
        // wheel-by-wheel soft-body/handling solver. Keep the change modest.
        Function.Call(Hash.SET_VEHICLE_CHEAT_POWER_INCREASE, vehicle.Handle, 8.0f);
        Function.Call(Hash.SET_VEHICLE_REDUCE_GRIP_LEVEL, vehicle.Handle, 1);
        Function.Call(Hash.SET_VEHICLE_REDUCE_GRIP, vehicle.Handle, true);
    }

    private static void ApplyCrashDamage(Vehicle vehicle, float speedLoss)
    {
        // SET_VEHICLE_DAMAGE uses offsets in the vehicle's local model space.
        // Add a front impact dent and lower engine health on larger impacts;
        // GTA still performs its normal collision/deformation handling too.
        float damage = Clamp(65.0f + speedLoss * 15.0f, 65.0f, 420.0f);
        float radius = Clamp(35.0f + speedLoss * 2.0f, 35.0f, 100.0f);
        Function.Call(Hash.SET_VEHICLE_DAMAGE, vehicle.Handle, 0.0f, 1.35f, 0.15f, damage, radius, true);

        float engineHealth = Function.Call<float>(Hash.GET_VEHICLE_ENGINE_HEALTH, vehicle.Handle);
        float nextEngineHealth = Math.Max(-4000.0f, engineHealth - speedLoss * 8.0f);
        Function.Call(Hash.SET_VEHICLE_ENGINE_HEALTH, vehicle.Handle, nextEngineHealth);
    }

    private void ResetTrackedVehicle()
    {
        _trackedVehicleHandle = 0;
        _previousSpeed = 0.0f;
        _previouslyColliding = false;
    }

    private static float Clamp(float value, float minimum, float maximum)
    {
        return Math.Max(minimum, Math.Min(maximum, value));
    }

    private static int Joaat(string value)
    {
        uint hash = 0;
        foreach (char character in value.ToLowerInvariant())
        {
            hash += character;
            hash += hash << 10;
            hash ^= hash >> 6;
        }

        hash += hash << 3;
        hash ^= hash >> 11;
        hash += hash << 15;
        return unchecked((int)hash);
    }
}
