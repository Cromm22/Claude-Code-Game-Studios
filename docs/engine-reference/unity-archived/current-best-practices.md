# Unity 6.3 LTS — Current Best Practices

**Last verified:** 2026-04-21

Modern Unity 6 patterns that may not be in the LLM's training data.
These are production-ready recommendations as of Unity 6.3 LTS.

---

## Project Setup

### Use Unity 6.3 LTS for Production
- **Tech Stream** (6.4+): Latest features, less stable
- **LTS** (6.3): Production-ready, 2-year support (until Dec 2027)

### Choose the Right Render Pipeline
- **URP (Universal)**: Mobile, cross-platform, good performance ✅ Recommended for most games
- **HDRP (High Definition)**: High-end PC/console, photorealistic
- **Built-in**: Deprecated, avoid for new projects

---

## Scripting

### Use C# 9+ Features (Unity 6 Supports C# 9)

```csharp
// ✅ Record types for data
public record PlayerData(string Name, int Level, float Health);

// ✅ Init-only properties
public class Config {
    public string GameMode { get; init; }
}

// ✅ Pattern matching
var result = enemy switch {
    Boss boss => boss.Enrage(),
    Minion minion => minion.Flee(),
    _ => null
};
```

### Async/Await for Asset Loading

```csharp
// ✅ Modern async pattern
public async Task<GameObject> LoadEnemyAsync(string key) {
    var handle = Addressables.LoadAssetAsync<GameObject>(key);
    return await handle.Task;
}
```

### Use Source Generators for Serialization (Unity 6+)

```csharp
// ✅ Source-generated serialization (faster, less reflection)
[GenerateSerializer]
public partial struct PlayerStats : IComponentData {
    public int Health;
    public int Mana;
}
```

---

## DOTS/ECS (Production-Ready in Unity 6.3 LTS)

### Use ISystem (Not ComponentSystem)

```csharp
// ✅ Modern unmanaged ISystem (Burst-compatible)
public partial struct MovementSystem : ISystem {
    public void OnCreate(ref SystemState state) { }

    public void OnUpdate(ref SystemState state) {
        foreach (var (transform, speed) in
            SystemAPI.Query<RefRW<LocalTransform>, RefRO<MoveSpeed>>()) {
            transform.ValueRW.Position += speed.ValueRO.Value * SystemAPI.Time.DeltaTime;
        }
    }
}
```

### Use IJobEntity for Parallel Jobs

```csharp
// ✅ IJobEntity (replaces IJobForEach)
[BurstCompile]
public partial struct DamageJob : IJobEntity {
    public float DeltaTime;

    void Execute(ref Health health, in DamageOverTime dot) {
        health.Value -= dot.DamagePerSecond * DeltaTime;
    }
}

// Schedule it
var job = new DamageJob { DeltaTime = SystemAPI.Time.DeltaTime };
job.ScheduleParallel();
```

---

## Input

### Use Input System Package (Not Legacy Input)

```csharp
// ✅ Input Actions (rebindable, cross-platform)
using UnityEngine.InputSystem;

public class PlayerInput : MonoBehaviour {
    private PlayerControls controls;

    void Awake() {
        controls = new PlayerControls();
        controls.Gameplay.Jump.performed += ctx => Jump();
    }

    void OnEnable() => controls.Enable();
    void OnDisable() => controls.Disable();
}
```

Create Input Actions asset in editor, generate C# class via inspector.

---

## UI

### Use UI Toolkit for Runtime UI (Production-Ready in Unity 6)

```csharp
// ✅ UI Toolkit (replaces UGUI for new projects)
using UnityEngine.UIElements;

public class MainMenu : MonoBehaviour {
    void OnEnable() {
        var root = GetComponent<UIDocument>().rootVisualElement;

        var playButton = root.Q<Button>("play-button");
        playButton.clicked += StartGame;

        var scoreLabel = root.Q<Label>("score");
        scoreLabel.text = $"High Score: {PlayerPrefs.GetInt("HighScore")}";
    }
}
```

**UXML** (UI structure) + **USS** (styling) = HTML/CSS-like workflow.

---

## Asset Management

### Use Addressables (Not Resources)

```csharp
// ✅ Addressables (async, memory-efficient)
using UnityEngine.AddressableAssets;

public async Task SpawnEnemyAsync(string enemyKey) {
    var handle = Addressables.InstantiateAsync(enemyKey);
    var enemy = await handle.Task;

    // Cleanup: release when destroyed
    Addressables.ReleaseInstance(enemy);
}
```

**Benefits:** Async loading, remote content delivery, better memory control.

---

## Rendering

### Use RenderGraph API for Custom Passes (URP/HDRP)

```csharp
// ✅ RenderGraph API (Unity 6+)
public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData) {
    using (var builder = renderGraph.AddRasterRenderPass<PassData>("My Pass", out var passData)) {
        // Setup pass
        builder.SetRenderFunc((PassData data, RasterGraphContext context) => {
            // Execute commands
        });
    }
}
```

**Replaces:** Old `CommandBuffer.Execute()` pattern.

---

## Performance

### Use Burst Compiler + Jobs System

```csharp
// ✅ Burst-compiled job (massive performance gain)
[BurstCompile]
struct ParticleUpdateJob : IJobParallelFor {
    public NativeArray<float3> Positions;
    public NativeArray<float3> Velocities;
    public float DeltaTime;

    public void Execute(int index) {
        Positions[index] += Velocities[index] * DeltaTime;
    }
}

// Schedule
var job = new ParticleUpdateJob {
    Positions = positions,
    Velocities = velocities,
    DeltaTime = Time.deltaTime
};
job.Schedule(positions.Length, 64).Complete();
```

**20-100x faster** than equivalent C# code.

---

### Use GPU Instancing for Repeated Objects

```csharp
// ✅ GPU Instancing (thousands of objects, minimal draw calls)
Graphics.RenderMeshInstanced(
    new RenderParams(material),
    mesh,
    0,
    matrices // NativeArray<Matrix4x4>
);
```

---

## Memory Management

### Use NativeContainers (Not Managed Arrays in Jobs)

```csharp
// ✅ NativeArray (no GC, Burst-compatible)
NativeArray<int> data = new NativeArray<int>(1000, Allocator.TempJob);
// ... use in job
data.Dispose(); // Manual cleanup required

// ✅ Or use using statement
using var data = new NativeArray<int>(1000, Allocator.TempJob);
// Auto-disposed
```

---

## Multiplayer

### Use Netcode for GameObjects (Official)

```csharp
// ✅ Unity's official netcode
using Unity.Netcode;

public class Player : NetworkBehaviour {
    private NetworkVariable<int> health = new NetworkVariable<int>(100);

    [ServerRpc]
    public void TakeDamageServerRpc(int damage) {
        health.Value -= damage;
    }
}
```

**Replaces:** UNet (deprecated), MLAPI (renamed to Netcode for GameObjects).

---

## Testing

### Use Unity Test Framework (NUnit-based)

```csharp
// ✅ Play Mode Test
[UnityTest]
public IEnumerator Player_TakesDamage_HealthDecreases() {
    var player = new GameObject().AddComponent<Player>();
    player.Health = 100;

    player.TakeDamage(25);
    yield return null; // Wait one frame

    Assert.AreEqual(75, player.Health);
}
```

---

## Debugging

### Use Logging Best Practices

```csharp
// ✅ Structured logging (Unity 6+)
using UnityEngine;

Debug.Log($"Player {playerName} scored {score} points");

// ✅ Conditional compilation for debug code
#if UNITY_EDITOR || DEVELOPMENT_BUILD
    Debug.DrawRay(transform.position, direction, Color.red);
#endif
```

---

## Summary: Unity 6 Tech Stack

| Feature | Use This (2026) | Avoid This (Legacy) |
|---------|------------------|----------------------|
| **Input** | Input System package | `Input` class |
| **UI** | UI Toolkit | UGUI (Canvas) |
| **ECS** | ISystem + IJobEntity | ComponentSystem |
| **Rendering** | URP + RenderGraph | Built-in pipeline |
| **Assets** | Addressables | Resources |
| **Jobs** | Burst + IJobParallelFor | Coroutines for heavy work |
| **Multiplayer** | Netcode for GameObjects | UNet |

---

---

## Large Open World Optimization (Added 2026-04-21)

### GPU Resident Drawer (URP) — High Priority for Terranova

Transfers static geometry batching to GPU, dramatically reducing CPU overhead for large scenes with many repeated meshes (trees, rocks, environment props).

**Requirements to enable:**
1. Graphics Settings → Shader Stripping → `BatchRendererGroup Variants` = **Keep All**
2. URP Asset → SRP Batcher = **Enabled**
3. URP Asset → GPU Resident Drawer = **Instanced Drawing**
4. Rendering Path = **Forward+** (recommended)
5. Mesh Renderers must: use static GI only, not use Light Probe Proxy Volume

**When to use**: Large open-world scenes with repeated meshes. Expected 2x+ improvement on CPU draw call overhead.

---

### Adaptive Probe Volumes — Replaces Manual Light Probes

Automatically generates light probe grids based on geometry density. Eliminates tedious manual probe placement for large worlds.

**Setup:**
1. Lighting → Light Probe System → **Adaptive Probe Volumes**
2. Create APV GameObject → Mode = **Global**
3. Set all lights to **Mixed** or **Baked**
4. Bake via Lighting window

**Why this matters for Terranova**: Open-world environments with dynamic time-of-day or atmospheric lighting benefit enormously from APV — no more dark patches or bright seams between probe regions.

---

### Netcode for GameObjects 2.0 — Distributed Authority (Co-op)

For Terranova's co-op mode (2–4 players, cooperative, not competitive):

```csharp
// ✅ Distributed Authority topology (Unity 6.0+)
// Players own their own objects — no central authority required
// Suitable for cooperative survival, NOT competitive PvP

using Unity.Netcode;

public class PlayerSurvival : NetworkBehaviour {
    // NetworkVariable syncs state to all clients
    private NetworkVariable<float> _oxygenLevel = new NetworkVariable<float>(100f);
    private NetworkVariable<float> _disturbanceLevel = new NetworkVariable<float>(0f);

    [ServerRpc(RequireOwnership = true)]
    public void GatherResourceServerRpc(ResourceType type, float amount) {
        // Server validates, adds disturbance, syncs state
        _disturbanceLevel.Value += amount * ResourceDisturbanceCost(type);
    }
}
```

**Note**: Distributed Authority is peer-to-peer. For an authoritative server running predator AI, consider Client-Server topology instead. The predator AI should always run server-side.

---

### Sentis (ML Inference) — For Predator Behavioral AI

Unity 6.3 includes Sentis as a core feature — runs ONNX models locally at game runtime. Viable path for predator behavioral intelligence without cloud dependency.

```csharp
// ✅ Sentis — local ML inference (Unity 6.3+)
using Unity.Sentis;

public class PredatorBehaviorAI : MonoBehaviour {
    [SerializeField] private ModelAsset _behaviorModel;
    private IWorker _worker;

    void Start() {
        var model = ModelLoader.Load(_behaviorModel);
        _worker = WorkerFactory.CreateWorker(BackendType.GPUCompute, model);
    }

    // Feed sensor data → get behavior output
    void Update() {
        using var input = new TensorFloat(sensorData);
        _worker.Execute(input);
        var output = _worker.PeekOutput() as TensorFloat;
        ApplyBehavior(output[0]); // behavior decision
    }
}
```

**Relevance**: Terranova's apex predator AI is the game's highest technical risk. Sentis allows training a behavior model offline and running it locally — a valid approach if custom Behavior Trees prove insufficient.

---

## Updated Tech Stack Summary (2026-04-21)

| Feature | Use This (2026) | Avoid This (Legacy) |
|---------|------------------|----------------------|
| **Input** | Input System package | `Input` class |
| **UI** | UI Toolkit | UGUI (Canvas) |
| **ECS** | ISystem + IJobEntity | ComponentSystem |
| **Rendering** | URP + Render Graph | Built-in pipeline, SetupRenderPasses |
| **Open World Perf** | GPU Resident Drawer | CPU-side batching |
| **Lighting** | Adaptive Probe Volumes | Manual Light Probe placement |
| **Assets** | Addressables | Resources |
| **Jobs** | Burst + IJobParallelFor | Coroutines for heavy work |
| **Multiplayer** | Netcode for GameObjects 2.0 | UNet |
| **AI/ML** | Sentis (local ONNX inference) | Cloud-only AI |
| **Object finding** | `FindObjectsByType<T>()` | `FindObjectsOfType<T>()` |

---

**Sources:**
- https://docs.unity3d.com/6000.0/Documentation/Manual/BestPracticeGuides.html
- https://docs.unity3d.com/Packages/com.unity.entities@1.3/manual/index.html
- https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/manual/index.html
- https://docs.unity3d.com/6000.3/Documentation/Manual/WhatsNewUnity63.html
- https://docs.unity3d.com/6000.0/Documentation/Manual/urp/gpu-resident-drawer.html
- https://docs.unity3d.com/6000.3/Documentation/Manual/com.unity.ai.inference.html
