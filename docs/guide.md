# User Guide

## Introduction

This guide will help you get started with the Ugly C2 FFI collision detection library. We'll cover installation, basic usage, common patterns, and optimization tips.

## What is Ugly C2 FFI?

Ugly C2 FFI is a high-performance 2D collision detection library that uses LuaJIT's FFI (Foreign Function Interface) to directly call optimized C code. It provides:

- **10-20x faster** collision detection than LuaBridge-based interfaces
- **Zero garbage collection** pressure during queries
- **Sub-microsecond** query times
- Support for circles, AABBs, and capsules
- Stateless spatial queries for efficient filtering

## Installation

### Quick Start

1. **Clone or download** the package
2. **Build** the native library:
   ```bash
   cd collision-ffi-package
   mkdir build && cd build
   cmake ..
   make
   ```
3. **Copy** the library to your project:
   - `build/ugly_c2_ffi.so` (Linux)
   - `build/ugly_c2_ffi.dll` (Windows)
   - `build/ugly_c2_ffi.dylib` (macOS)

### LuaRocks Installation

```bash
luarocks make collision-ffi-package/collision-ffi-1.0.0-1.rockspec
```

### Manual Installation

Copy these files to your project:

**Required:**
- `lua/collision_ffi.lua` - Main Lua module
- `build/ugly_c2_ffi.so` (or .dll/.dylib) - Native library

**Optional:**
- `lua/collision/` - Additional Lua modules
- `examples/` - Example scripts

## Basic Usage

### Step 1: Load the Module

```lua
local ffi = require("ffi")
local collision = require("collision_ffi")
```

### Step 2: Create a Collision Layer

```lua
-- Parameters: cell_size, max_collisions, max_manifolds
local layer = collision.new(64.0, 4096, 2048)
```

**Choosing cell_size:**
- Small objects (10-50 units): 20-64
- Medium objects (50-200 units): 100-200
- Large objects (200+ units): 300-500

**Rule of thumb:** Cell size should be 2-4x your average object size.

### Step 3: Add Shapes

```lua
-- Add a circle
layer:setCircle(1, 100.0, 100.0, 25.0)

-- Add an AABB (rectangle)
layer:setAABB(2, 150.0, 150.0, 200.0, 200.0)

-- Add a capsule
layer:setCapsule(3, 100.0, 100.0, 200.0, 200.0, 10.0)
```

**ID numbers** must be unique for each shape.

### Step 4: Check for Collisions

```lua
-- Check what shape 1 is colliding with
local ids, count = layer:getCollisions(1)

if ids and count > 0 then
    for i = 0, count - 1 do
        print("Shape 1 collides with shape:", ids[i])
    end
else
    print("Shape 1 has no collisions")
end
```

### Step 5: Get Collision Details

```lua
-- Get collision manifolds (contact information)
local data, count = layer:getManifolds(1)

if data and count > 0 then
    for i = 0, count - 1 do
        local offset = i * 5
        local nx = data[offset]      -- Normal X
        local ny = data[offset + 1]  -- Normal Y
        local cx = data[offset + 2]  -- Contact point X
        local cy = data[offset + 3]  -- Contact point Y
        local depth = data[offset + 4]  -- Penetration depth
        
        print(string.format(
            "Collision: normal=(%.2f,%.2f) depth=%.2f",
            nx, ny, depth
        ))
    end
end
```

### Step 6: Update Each Frame

```lua
function update()
    -- Reset buffers before queries
    layer:resetBuffers()
    
    -- Update shape positions
    layer:setCircle(1, new_x, new_y, radius)
    
    -- Check collisions
    local ids, count = layer:getCollisions(1)
    -- ... handle collisions ...
end
```

### Step 7: Clean Up

```lua
-- When done, free resources
layer:delete()
```

## Common Patterns

### Pattern 1: Simple Collision Detection

```lua
-- Setup
local layer = collision.new(64.0, 1024, 512)

-- Add player and enemies
layer:setCircle(1, player.x, player.y, 20)  -- Player
for i, enemy in ipairs(enemies) do
    layer:setCircle(i + 10, enemy.x, enemy.y, 15)
end

-- Check player collisions
local ids, count = layer:getCollisions(1)
if ids and count > 0 then
    for i = 0, count - 1 do
        local enemy_id = ids[i]
        -- Handle collision with enemy
    end
end

-- Reset for next frame
layer:resetBuffers()
```

### Pattern 2: Spatial Queries (Mouse Picking)

```lua
-- Find what's under the mouse
local mx, my = love.mouse.getPosition()
local ids, count = layer:queryPoint(mx, my)

if ids and count > 0 then
    print("Clicked on", count, "objects")
    for i = 0, count - 1 do
        print("  Object ID:", ids[i])
    end
end
```

### Pattern 3: Frustum Culling

```lua
-- Only process objects in view
local view_x, view_y = 0, 0
local view_w, view_h = 800, 600

local ids, count = layer:queryAABB(view_x, view_y, view_x + view_w, view_y + view_h)

-- Only render/update objects in view
if ids and count > 0 then
    for i = 0, count - 1 do
        renderObject(ids[i])
    end
end
```

### Pattern 4: Physics Response

```lua
function updatePhysics(dt)
    -- Update positions
    for id, obj in pairs(objects) do
        obj.x = obj.x + obj.vx * dt
        obj.y = obj.y + obj.vy * dt
        layer:setCircle(id, obj.x, obj.y, obj.radius)
    end
    
    -- Check and resolve collisions
    for id, obj in pairs(objects) do
        local data, count = layer:getManifolds(id)
        if data and count > 0 then
            for i = 0, count - 1 do
                local offset = i * 5
                local nx = data[offset]
                local ny = data[offset + 1]
                local depth = data[offset + 4]
                
                -- Move out of collision
                obj.x = obj.x + nx * depth
                obj.y = obj.y + ny * depth
                
                -- Reflect velocity
                local dot = obj.vx * nx + obj.vy * ny
                obj.vx = obj.vx - 2 * dot * nx
                obj.vy = obj.vy - 2 * dot * ny
            end
        end
    end
    
    layer:resetBuffers()
end
```

### Pattern 5: Batch Queries

```lua
-- Check multiple important objects at once
local important_ids = {1, 5, 10, 25, 50, 100}
local results, count = layer:getCollisionsBatch(important_ids)

if results and count > 0 then
    for i = 0, count - 1 do
        print("Collision involving:", results[i])
    end
end
```

## Optimization Tips

### 1. Choose the Right Cell Size

**Too small:** Many cells, poor cache performance  
**Too large:** Many objects per cell, slow queries

**Test different values:**
```lua
-- Try these and measure performance
local cell_sizes = {32, 64, 128, 256}
```

### 2. Size Buffers Appropriately

**Conservative:** `max_collisions = num_shapes * 8`  
**High density:** `max_collisions = num_shapes * 16`

If you see warnings about capacity, increase buffers.

### 3. Reuse Layer Handles

```lua
-- BAD: Creating new layer each frame
function update()
    local layer = collision.new(64, 4096, 2048)
    -- ...
    layer:delete()
end

-- GOOD: Create once, reuse
local layer = collision.new(64, 4096, 2048)

function update()
    layer:resetBuffers()
    -- ...
end
```

### 4. Use Batch Operations

```lua
-- BAD: Many individual queries
for i = 1, 100 do
    layer:getCollisions(i)
end

-- GOOD: One batch query
local ids = {}
for i = 1, 100 do ids[i] = i end
layer:getCollisionsBatch(ids)
```

### 5. Filter Before Checking

```lua
-- BAD: Check all objects
for id = 1, 1000 do
    layer:getCollisions(id)
end

-- GOOD: Filter by region first
local nearby = layer:queryAABB(x - 100, y - 100, x + 100, y + 100)
-- Then check collisions only for nearby objects
```

### 6. Profile Real Workloads

```lua
-- Measure actual performance
local start = os.clock()
-- Run your collision detection
local elapsed = os.clock() - start
print(string.format("%.3f ms", elapsed * 1000))
```

## Troubleshooting

### Problem: "Failed to load ugly_c2_ffi library"

**Solution:**
1. Ensure the library file exists:
   - Linux: `ugly_c2_ffi.so`
   - Windows: `ugly_c2_ffi.dll`
   - macOS: `ugly_c2_ffi.dylib`
2. Set the library path:
   ```lua
   package.cpath = package.cpath .. ";./build/?.so"
   ```

### Problem: Segmentation Fault

**Causes:**
- Using layer after deletion
- Buffer capacity exceeded
- Invalid shape IDs

**Solution:**
- Don't use layer after `delete()`
- Increase buffer sizes
- Check that IDs are valid

### Problem: Poor Performance

**Check:**
1. Cell size appropriate? (2-4x object size)
2. Buffers large enough? (no capacity warnings)
3. Reusing layer handle? (not creating new each frame)
4. Using batch operations? (for multiple queries)

### Problem: Wrong Collision Results

**Check:**
1. Calling `resetBuffers()` each frame?
2. Updating shape positions before queries?
3. Using correct coordinate system?

## Advanced Topics

### Custom Collision Filtering

The library checks all shapes against each other. For custom filtering:

```lua
-- Get all collisions
local ids, count = layer:getCollisions(id)

-- Filter by type
if ids and count > 0 then
    for i = 0, count - 1 do
        local other_id = ids[i]
        if object_types[other_id] == "enemy" then
            -- Handle enemy collision
        end
    end
end
```

### Multiple Layers

For different collision groups:

```lua
local player_layer = collision.new(64, 1024, 512)
local enemy_layer = collision.new(64, 1024, 512)
local world_layer = collision.new(64, 4096, 2048)

-- Check player vs world
local ids, count = player_layer:getCollisions(1)
```

### Memory Management

The library uses preallocated buffers. Memory usage:

```
Total memory ≈ (max_collisions * 4) + (max_manifolds * 20) bytes

Example: 4096 collisions, 2048 manifolds
         = (4096 * 4) + (2048 * 20)
         = 16,384 + 40,960
         = 57,344 bytes (~56 KB)
```

## Performance Benchmarks

Run the included benchmarks:

```bash
# Basic performance test
luajit benchmark/benchmark.lua

# Comparison with HC library
luajit benchmark/hc_comparison.lua
```

Expected results (2000 shapes, 500 frames):
- Frame time: ~3.7 ms
- Throughput: ~270 FPS
- Collisions: ~4.8 million detected

## Next Steps

1. **Run examples:** `luajit examples/basic.lua`
2. **Try Love2D demo:** `love love2d-example/`
3. **Run benchmarks:** See actual performance
4. **Read API docs:** `docs/api.md` for complete reference

## Getting Help

- Check `examples/` for working code
- Read `docs/api.md` for detailed API
- Review `benchmark/` for performance patterns
- See `USAGE_EXAMPLES.md` for more patterns

## Best Practices Summary

✅ **Do:**
- Reuse layer handles
- Call `resetBuffers()` each frame
- Choose appropriate cell size
- Use batch operations when possible
- Profile with real data

❌ **Don't:**
- Create new layers each frame
- Use after deletion
- Exceed buffer capacity
- Store result pointers across frames
- Forget to update positions before queries

## Conclusion

Ugly C2 FFI provides high-performance collision detection for Lua applications. By following this guide and the best practices, you can achieve excellent performance in your games and simulations.

Remember: **profile, don't guess!** Test with your actual data and adjust parameters accordingly.