# Usage Examples

This document provides practical examples of using the optimized FFI collision detection library.

## Example 1: Basic Setup and Collision Detection

```lua
local ffi = require("ffi")

-- FFI definitions (see collision_ffi.lua for complete definitions)
ffi.cdef[[
typedef struct { void *data; size_t size; size_t element_size; } ArrayHandle;
typedef struct CollisionLayer CollisionLayer;
typedef struct { CollisionLayer *layer; void *cb; void *mb; } LayerHandle;
LayerHandle* layer_new_with_buffers(float, size_t, size_t);
void layer_delete(LayerHandle*);
void layer_set_circle(LayerHandle*, uint32_t, float, float, float);
void layer_set_AABB(LayerHandle*, uint32_t, float, float, float, float);
ArrayHandle layer_getCollisions(LayerHandle*, uint32_t);
ArrayHandle layer_getManifolds(LayerHandle*, uint32_t);
]]

local C = ffi.load("./build/ugly_c2_ffi.so")

-- Create layer for 1000 objects
local layer = C.layer_new_with_buffers(64.0, 8192, 4096)

-- Add player
C.layer_set_circle(layer, 1, 400.0, 300.0, 20.0)

-- Add enemy
C.layer_set_circle(layer, 2, 450.0, 300.0, 15.0)

-- Check for collision
local result = C.layer_getCollisions(layer, 1)
if result.data ~= nil and result.size > 0 then
    local ids = ffi.cast("uint32_t*", result.data)
    print("Player collides with enemy " .. ids[0])
    
    -- Get collision details
    local manifolds = C.layer_getManifolds(layer, 1)
    if manifolds.data ~= nil then
        local data = ffi.cast("float*", manifolds.data)
        print("Collision normal: " .. data[0] .. ", " .. data[1])
        print("Penetration depth: " .. data[4])
    end
end

C.layer_delete(layer)
```

## Example 2: Game Loop with Multiple Objects

```lua
local ffi = require("ffi")

-- Load FFI definitions
ffi.cdef[[
typedef struct { void *data; size_t size; size_t element_size; } ArrayHandle;
typedef struct CollisionLayer CollisionLayer;
typedef struct { CollisionLayer *layer; void *cb; void *mb; } LayerHandle;
LayerHandle* layer_new_with_buffers(float, size_t, size_t);
void layer_delete(LayerHandle*);
void layer_set_circle(LayerHandle*, uint32_t, float, float, float);
void layer_set_AABB(LayerHandle*, uint32_t, float, float, float, float);
ArrayHandle layer_getCollisions(LayerHandle*, uint32_t);
]]

local C = ffi.load("./build/ugly_c2_ffi.so")

-- Initialize
local layer = C.layer_new_with_buffers(64.0, 4096, 2048)
local objects = {}

-- Create 100 game objects
for i = 1, 100 do
    objects[i] = {
        id = i,
        x = math.random(100, 700),
        y = math.random(100, 500),
        radius = math.random(10, 25),
        vx = (math.random() - 0.5) * 100,
        vy = (math.random() - 0.5) * 100
    }
    C.layer_set_circle(layer, i, objects[i].x, objects[i].y, objects[i].radius)
end

-- Game loop
function update(dt)
    -- Reset buffers for new frame
    -- (Note: reset_buffers not exposed in minimal example)
    
    -- Update positions
    for _, obj in ipairs(objects) do
        obj.x = obj.x + obj.vx * dt
        obj.y = obj.y + obj.vy * dt
        
        -- Bounce off walls
        if obj.x < obj.radius or obj.x > 800 - obj.radius then
            obj.vx = -obj.vx
        end
        if obj.y < obj.radius or obj.y > 600 - obj.radius then
            obj.vy = -obj.vy
        end
        
        -- Update collision layer
        C.layer_set_circle(layer, obj.id, obj.x, obj.y, obj.radius)
    end
    
    -- Check collisions
    for _, obj in ipairs(objects) do
        local result = C.layer_getCollisions(layer, obj.id)
        if result.data ~= nil and result.size > 0 then
            -- Handle collision
            handleCollision(obj.id, result)
        end
    end
end

function handleCollision(id, result)
    local ids = ffi.cast("uint32_t*", result.data)
    for i = 0, result.size - 1 do
        print("Object " .. id .. " collides with " .. ids[i])
    end
end

function cleanup()
    C.layer_delete(layer)
end
```

## Example 3: Spatial Queries for AI

```lua
local ffi = require("ffi")

ffi.cdef[[
typedef struct { void *data; size_t size; size_t element_size; } ArrayHandle;
typedef struct CollisionLayer CollisionLayer;
typedef struct { CollisionLayer *layer; void *cb; void *mb; } LayerHandle;
LayerHandle* layer_new_with_buffers(float, size_t, size_t);
void layer_delete(LayerHandle*);
void layer_set_circle(LayerHandle*, uint32_t, float, float, float);
ArrayHandle layer_queryPoint(LayerHandle*, float, float);
ArrayHandle layer_queryAABB(LayerHandle*, float, float, float, float);
]]

local C = ffi.load("./build/ugly_c2_ffi.so")
local layer = C.layer_new_with_buffers(64.0, 2048, 1024)

-- Add game objects
for i = 1, 50 do
    C.layer_set_circle(layer, i, 
        math.random(100, 700), 
        math.random(100, 500), 
        math.random(15, 30))
end

-- AI: Find all objects near a point (e.g., explosion)
function findObjectsNearPoint(x, y, radius)
    local nearby = {}
    local result = C.layer_queryAABB(layer, 
        x - radius, y - radius, 
        x + radius, y + radius)
    
    if result.data ~= nil then
        local ids = ffi.cast("uint32_t*", result.data)
        for i = 0, result.size - 1 do
            table.insert(nearby, ids[i])
        end
    end
    return nearby
end

-- AI: Check if point is occupied
function isPointOccupied(x, y)
    local result = C.layer_queryPoint(layer, x, y)
    return result.data ~= nil and result.size > 0
end

-- Usage
local enemies = findObjectsNearPoint(400, 300, 100)
print("Enemies in blast radius: " .. #enemies)

if isPointOccupied(450, 350) then
    print("Cannot move there - occupied!")
end

C.layer_delete(layer)
```

## Example 4: Batch Queries for Performance

```lua
local ffi = require("ffi")

ffi.cdef[[
typedef struct { void *data; size_t size; size_t element_size; } ArrayHandle;
typedef struct CollisionLayer CollisionLayer;
typedef struct { CollisionLayer *layer; void *cb; void *mb; } LayerHandle;
LayerHandle* layer_new_with_buffers(float, size_t, size_t);
void layer_delete(LayerHandle*);
void layer_set_circle(LayerHandle*, uint32_t, float, float, float);
ArrayHandle layer_getCollisionsBatch(LayerHandle*, uint32_t*, size_t);
]]

local C = ffi.load("./build/ugly_c2_ffi.so")
local layer = C.layer_new_with_buffers(64.0, 4096, 2048)

-- Add objects
for i = 1, 100 do
    C.layer_set_circle(layer, i, 
        math.random(100, 700), 
        math.random(100, 500), 
        math.random(10, 20))
end

-- Batch query - much faster than individual queries
function batchCollisionCheck(objectIds)
    local idArray = ffi.new("uint32_t[?]", #objectIds)
    for i, id in ipairs(objectIds) do
        idArray[i-1] = id  -- LuaJIT FFI uses 0-based indexing
    end
    
    local result = C.layer_getCollisionsBatch(layer, idArray, #objectIds)
    
    if result.data ~= nil then
        local ids = ffi.cast("uint32_t*", result.data)
        local collisions = {}
        for i = 0, result.size - 1 do
            table.insert(collisions, ids[i])
        end
        return collisions
    end
    return {}
end

-- Check collisions for multiple important objects at once
local importantObjects = {1, 5, 10, 25, 50, 75, 100}
local allCollisions = batchCollisionCheck(importantObjects)
print("Total collisions: " .. #allCollisions)

C.layer_delete(layer)
```

## Example 5: Physics Response with Manifolds

```lua
local ffi = require("ffi")

ffi.cdef[[
typedef struct { void *data; size_t size; size_t element_size; } ArrayHandle;
typedef struct CollisionLayer CollisionLayer;
typedef struct { CollisionLayer *layer; void *cb; void *mb; } LayerHandle;
LayerHandle* layer_new_with_buffers(float, size_t, size_t);
void layer_delete(LayerHandle*);
void layer_set_circle(LayerHandle*, uint32_t, float, float, float);
ArrayHandle layer_getManifolds(LayerHandle*, uint32_t);
]]

local C = ffi.load("./build/ugly_c2_ffi.so")
local layer = C.layer_new_with_buffers(64.0, 1024, 512)

-- Physics object
local player = {
    id = 1,
    x = 400, y = 300,
    vx = 0, vy = 0,
    radius = 20
}

C.layer_set_circle(layer, player.id, player.x, player.y, player.radius)

-- Simple physics update
function updatePhysics(dt)
    -- Apply gravity
    player.vy = player.vy + 500 * dt
    
    -- Update position
    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt
    
    -- Update collision layer
    C.layer_set_circle(layer, player.id, player.x, player.y, player.radius)
    
    -- Check for collisions and resolve
    local manifolds = C.layer_getManifolds(layer, player.id)
    if manifolds.data ~= nil then
        local data = ffi.cast("float*", manifolds.data)
        local count = manifolds.size / 5  -- 5 floats per manifold
        
        for i = 0, count - 1 do
            local offset = i * 5
            local nx = data[offset]      -- normal x
            local ny = data[offset + 1]  -- normal y
            local depth = data[offset + 4]  -- penetration depth
            
            -- Resolve collision by moving out along normal
            player.x = player.x + nx * depth
            player.y = player.y + ny * depth
            
            -- Reflect velocity (simple bounce)
            local dot = player.vx * nx + player.vy * ny
            player.vx = player.vx - 2 * dot * nx
            player.vy = player.vy - 2 * dot * ny
            
            -- Apply friction
            player.vx = player.vx * 0.8
            player.vy = player.vy * 0.8
        end
        
        -- Update position after resolution
        C.layer_set_circle(layer, player.id, player.x, player.y, player.radius)
    end
end

-- Game loop
function gameLoop(dt)
    updatePhysics(dt)
    -- Render...
end

C.layer_delete(layer)
```

## Example 6: Object Pooling for Performance

```lua
local ffi = require("ffi")

ffi.cdef[[
typedef struct { void *data; size_t size; size_t element_size; } ArrayHandle;
typedef struct CollisionLayer CollisionLayer;
typedef struct { CollisionLayer *layer; void *cb; void *mb; } LayerHandle;
LayerHandle* layer_new_with_buffers(float, size_t, size_t);
void layer_delete(LayerHandle*);
void layer_set_circle(LayerHandle*, uint32_t, float, float, float);
void layer_remove(LayerHandle*, uint32_t);
ArrayHandle layer_getCollisions(LayerHandle*, uint32_t);
]]

local C = ffi.load("./build/ugly_c2_ffi.so")
local layer = C.layer_new_with_buffers(64.0, 8192, 4096)

-- Object pool
local MAX_OBJECTS = 1000
local objects = {}
local freeIds = {}

-- Initialize pool
for i = 1, MAX_OBJECTS do
    freeIds[i] = i
    objects[i] = {active = false}
end

-- Spawn object
function spawnObject(x, y, radius)
    if #freeIds == 0 then return nil end
    
    local id = table.remove(freeIds)
    local obj = objects[id]
    
    obj.active = true
    obj.x = x
    obj.y = y
    obj.radius = radius
    obj.vx = (math.random() - 0.5) * 100
    obj.vy = (math.random() - 0.5) * 100
    
    C.layer_set_circle(layer, id, x, y, radius)
    return id
end

-- Despawn object
function despawnObject(id)
    if not objects[id].active then return end
    
    objects[id].active = false
    C.layer_remove(layer, id)
    table.insert(freeIds, id)
end

-- Update all active objects
function updateObjects(dt)
    for id = 1, MAX_OBJECTS do
        local obj = objects[id]
        if obj.active then
            -- Update position
            obj.x = obj.x + obj.vx * dt
            obj.y = obj.y + obj.vy * dt
            
            -- Check collisions
            local result = C.layer_getCollisions(layer, id)
            if result.data ~= nil and result.size > 0 then
                handleCollision(id, result)
            end
            
            -- Update collision layer
            C.layer_set_circle(layer, id, obj.x, obj.y, obj.radius)
            
            -- Despawn if out of bounds
            if obj.x < 0 or obj.x > 800 or obj.y < 0 or obj.y > 600 then
                despawnObject(id)
            end
        end
    end
end

-- Spawn some objects
for i = 1, 100 do
    spawnObject(
        math.random(100, 700),
        math.random(100, 500),
        math.random(10, 20)
    )
end

C.layer_delete(layer)
```

## Best Practices

1. **Reuse Layer Handles**: Create once, reset each frame
2. **Size Buffers Appropriately**: Monitor capacity usage
3. **Use Batch Operations**: When checking multiple objects
4. **Leverage Stateless Queries**: For spatial filtering without side effects
5. **Profile Real Workloads**: Adjust cell_size and buffer sizes based on actual data
6. **Object Pooling**: For frequent add/remove operations
7. **Warm Up JIT**: Run a few frames before timing critical sections

## Common Patterns

| Pattern | Use Case | Functions |
|---------|----------|-----------|
| Player vs World | Character collision | `layer_getCollisions` |
| Area Detection | Explosions, abilities | `layer_queryAABB` |
| Mouse Picking | Selection, targeting | `layer_queryPoint` |
| Physics Resolution | Collision response | `layer_getManifolds` |
| Broadphase Culling | Reduce checks | `layer_queryAABB` + `layer_getCollisions` |
| Batch Processing | Many objects | `layer_getCollisionsBatch` |