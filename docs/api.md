# API Reference

## Module: collision_ffi

The main module for high-performance 2D collision detection using LuaJIT FFI.

### Functions

#### `collision.new(cell_size, max_collisions, max_manifolds)`

Creates a new collision layer with preallocated buffers.

**Parameters:**
- `cell_size` (number): Size of grid cells for spatial hashing. Optimal value is 2-4x the average object size.
- `max_collisions` (number): Maximum number of collision results to buffer per frame.
- `max_manifolds` (number): Maximum number of manifold results to buffer per frame.

**Returns:** Layer handle (table with metatable)

**Example:**
```lua
local layer = collision.new(64.0, 4096, 2048)
```

---

## Layer Methods

All layer methods operate on a layer handle returned by `collision.new()`.

### `layer:delete()`

Frees all resources associated with the layer. After calling this, the layer handle must not be used.

**Example:**
```lua
layer:delete()
```

---

### `layer:setCircle(id, x, y, r)`

Adds or updates a circle shape in the layer.

**Parameters:**
- `id` (number): Unique identifier for the shape
- `x` (number): X coordinate of circle center
- `y` (number): Y coordinate of circle center
- `r` (number): Radius of circle

**Example:**
```lua
layer:setCircle(1, 100.0, 100.0, 25.0)
```

---

### `layer:setAABB(id, minx, miny, maxx, maxy)`

Adds or updates an axis-aligned bounding box in the layer.

**Parameters:**
- `id` (number): Unique identifier for the shape
- `minx` (number): Minimum X coordinate
- `miny` (number): Minimum Y coordinate
- `maxx` (number): Maximum X coordinate
- `maxy` (number): Maximum Y coordinate

**Example:**
```lua
layer:setAABB(2, 150.0, 150.0, 200.0, 200.0)
```

---

### `layer:setCapsule(id, ax, ay, bx, by, r)`

Adds or updates a capsule shape in the layer.

**Parameters:**
- `id` (number): Unique identifier for the shape
- `ax` (number): X coordinate of first endpoint
- `ay` (number): Y coordinate of first endpoint
- `bx` (number): X coordinate of second endpoint
- `by` (number): Y coordinate of second endpoint
- `r` (number): Radius of capsule

**Example:**
```lua
layer:setCapsule(3, 100.0, 100.0, 200.0, 200.0, 10.0)
```

---

### `layer:remove(id)`

Removes a shape from the layer.

**Parameters:**
- `id` (number): Identifier of shape to remove

**Example:**
```lua
layer:remove(1)
```

---

### `layer:getCollisions(id)`

Returns all shapes that are colliding with the specified shape.

**Parameters:**
- `id` (number): Identifier of shape to check

**Returns:**
- `ids` (cdata): `uint32_t*` array of colliding shape identifiers, or `nil` if no collisions
- `count` (number): Number of collisions found

**Example:**
```lua
local ids, count = layer:getCollisions(1)
if ids and count > 0 then
    for i = 0, count - 1 do
        print("Collides with shape:", ids[i])
    end
end
```

**Note:** The returned array is only valid until the next call to any layer method that modifies buffers.

---

### `layer:getCollisionsBatch(ids)`

Queries collisions for multiple shapes at once. More efficient than individual queries when checking many shapes.

**Parameters:**
- `ids` (table): Array of shape identifiers to check

**Returns:**
- `ids` (cdata): `uint32_t*` array of collision results
- `count` (number): Number of results

**Example:**
```lua
local shape_ids = {1, 5, 10, 25, 50}
local results, count = layer:getCollisionsBatch(shape_ids)
if results and count > 0 then
    for i = 0, count - 1 do
        print("Collision with shape:", results[i])
    end
end
```

**Performance:** Batch queries reduce Lua/C boundary crossings, improving performance when checking multiple shapes.

---

### `layer:getManifolds(id)`

Returns detailed collision information (manifolds) for a shape. Each manifold contains contact normal, contact point, and penetration depth.

**Parameters:**
- `id` (number): Identifier of shape to check

**Returns:**
- `data` (cdata): `float*` array of manifold data (5 floats per manifold), or `nil` if no collisions
- `count` (number): Number of manifolds (not floats)

**Manifold Data Layout:**
For each manifold `i` (0-indexed):
- `data[i*5 + 0]` = normal_x (collision normal X component)
- `data[i*5 + 1]` = normal_y (collision normal Y component)
- `data[i*5 + 2]` = contact_x (contact point X coordinate)
- `data[i*5 + 3]` = contact_y (contact point Y coordinate)
- `data[i*5 + 4]` = depth (penetration depth)

**Example:**
```lua
local data, count = layer:getManifolds(1)
if data and count > 0 then
    for i = 0, count - 1 do
        local offset = i * 5
        local nx = data[offset]
        local ny = data[offset + 1]
        local cx = data[offset + 2]
        local cy = data[offset + 3]
        local depth = data[offset + 4]
        
        print(string.format(
            "Manifold %d: normal=(%.2f,%.2f) contact=(%.2f,%.2f) depth=%.2f",
            i + 1, nx, ny, cx, cy, depth
        ))
    end
end
```

**Use Case:** Essential for physics response and collision resolution.

---

### `layer:queryPoint(x, y)`

Finds all shapes that contain the specified point. This is a stateless query that does not modify the layer.

**Parameters:**
- `x` (number): X coordinate of point
- `y` (number): Y coordinate of point

**Returns:**
- `ids` (cdata): `uint32_t*` array of shape identifiers, or `nil` if no shapes found
- `count` (number): Number of shapes found

**Example (Mouse Picking):**
```lua
local mx, my = 150.0, 150.0
local ids, count = layer:queryPoint(mx, my)
if ids and count > 0 then
    print("Shapes under mouse:", count)
    for i = 0, count - 1 do
        print("  Shape " .. ids[i])
    end
end
```

**Performance:** O(log n) average case with spatial hashing.

---

### `layer:queryAABB(minx, miny, maxx, maxy)`

Finds all shapes that intersect the specified axis-aligned bounding box. This is a stateless query that does not modify the layer.

**Parameters:**
- `minx` (number): Minimum X coordinate of query region
- `miny` (number): Minimum Y coordinate of query region
- `maxx` (number): Maximum X coordinate of query region
- `maxy` (number): Maximum Y coordinate of query region

**Returns:**
- `ids` (cdata): `uint32_t*` array of shape identifiers, or `nil` if no shapes found
- `count` (number): Number of shapes found

**Example (Frustum Culling):**
```lua
local ids, count = layer:queryAABB(0, 0, 800, 600)
print("Shapes in view:", count)
```

**Performance:** O(k + log n) where k is number of results.

---

### `layer:resetBuffers()`

Resets internal buffer counters without reallocating memory. Must be called at the beginning of each frame before performing any queries.

**Important:** This does not remove shapes from the layer - it only resets the query result buffers.

**Example:**
```lua
function update()
    layer:resetBuffers()
    -- Perform collision checks and queries...
end
```

**Performance:** O(1) - just resets counters.

---

## Raw C Interface

For advanced users who need direct access to the C API:

### `collision.C`

The raw FFI C interface is available as `collision.C`. This provides direct access to the C functions without Lua wrappers.

**Example:**
```lua
local C = collision.C
local handle = C.layer_new_with_buffers(64.0, 4096, 2048)
C.layer_set_circle(handle, 1, 100.0, 100.0, 25.0)
-- ... use C API directly ...
C.layer_delete(handle)
```

**Warning:** Using the raw C interface bypasses Lua error checking and memory safety. Use with caution.

---

## Best Practices

### Layer Lifetime
- Create layers once and reuse them
- Call `resetBuffers()` each frame before queries
- Call `delete()` when layer is no longer needed

### Buffer Sizing
- Set `max_collisions` to 8-16x number of shapes for typical use
- Set `max_manifolds` to half of `max_collisions`
- Monitor capacity usage and adjust if warnings appear

### Query Performance
- Use `queryPoint()` and `queryAABB()` for spatial filtering before detailed checks
- Use `getCollisionsBatch()` when checking multiple shapes
- Cache results when possible within a frame

### Memory Management
- All query results are borrowed from preallocated buffers
- Results are only valid until next `resetBuffers()` call
- Do not store pointers to result arrays across frames

## Error Handling

All layer methods will raise Lua errors if:
- Layer handle is invalid or deleted
- Buffer capacity is exceeded
- Invalid parameters are provided

Check return values for `nil` results when appropriate.

## Thread Safety

The collision layer is **not** thread-safe. All operations must be performed from the same thread. For multi-threaded applications, create separate layers for each thread.

## Performance Characteristics

| Operation | Time Complexity | Notes |
|-----------|----------------|-------|
| `setCircle/setAABB/setCapsule` | O(1) | Amortized constant |
| `getCollisions` | O(1) average | Depends on object density |
| `getManifolds` | O(1) average | Depends on collision count |
| `queryPoint` | O(log n) average | Spatial hash lookup |
| `queryAABB` | O(k + log n) | k = results in region |
| `resetBuffers` | O(1) | Just resets counters |

## See Also

- [Examples](../examples/) - Usage examples
- [Benchmarks](../benchmark/) - Performance tests
- [Love2D Example](../love2d-example/) - Interactive demo