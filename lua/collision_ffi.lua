--[[
    Ugly C2 FFI - High-performance 2D collision detection
    LuaJIT FFI bindings for optimized collision detection
]]

local ffi = require("ffi")

-- FFI definitions
ffi.cdef[[
typedef struct {
    void *data;
    size_t size;
    size_t element_size;
} ArrayHandle;

typedef struct CollisionLayer CollisionLayer;

typedef struct {
    CollisionLayer *layer;
    void *collision_buffer;
    void *manifold_buffer;
} LayerHandle;

LayerHandle* layer_new_with_buffers(float cell_size, size_t max_collisions, size_t max_manifolds);
void layer_delete(LayerHandle *handle);
void layer_set_circle(LayerHandle *handle, uint32_t id, float x, float y, float r);
void layer_set_AABB(LayerHandle *handle, uint32_t id, float minx, float miny, float maxx, float maxy);
void layer_set_Capsule(LayerHandle *handle, uint32_t id, float ax, float ay, float bx, float by, float r);
void layer_remove(LayerHandle *handle, uint32_t id);
ArrayHandle layer_getCollisions(LayerHandle *handle, uint32_t id);
ArrayHandle layer_getCollisionsBatch(LayerHandle *handle, uint32_t *ids, size_t num_ids);
ArrayHandle layer_getManifolds(LayerHandle *handle, uint32_t id);
ArrayHandle layer_queryPoint(LayerHandle *handle, float x, float y);
ArrayHandle layer_queryAABB(LayerHandle *handle, float minx, float miny, float maxx, float maxy);
void layer_reset_buffers(LayerHandle *handle);
]]

-- Load the native library
local C
local ok, err = pcall(function()
    C = ffi.load("./build/ugly_c2_ffi.so")
end)

if not ok then
    -- Try other common paths
    ok, err = pcall(function()
        C = ffi.load("ugly_c2_ffi")
    end)
end

if not ok then
    error("Failed to load ugly_c2_ffi library: " .. tostring(err))
end

-- Module table
local collision = {}

-- Create a new collision layer
function collision.new(cell_size, max_collisions, max_manifolds)
    cell_size = cell_size or 64.0
    max_collisions = max_collisions or 4096
    max_manifolds = max_manifolds or 2048
    
    local handle = C.layer_new_with_buffers(cell_size, max_collisions, max_manifolds)
    if handle == nil then
        error("Failed to create collision layer")
    end
    
    return setmetatable({
        _handle = handle,
        _deleted = false
    }, { __index = collision.layer_mt })
end

-- Layer metatable (instance methods)
collision.layer_mt = {}

function collision.layer_mt:delete()
    if not self._deleted and self._handle then
        C.layer_delete(self._handle)
        self._handle = nil
        self._deleted = true
    end
end

function collision.layer_mt:setCircle(id, x, y, r)
    assert(not self._deleted, "Layer has been deleted")
    C.layer_set_circle(self._handle, id, x, y, r)
end

function collision.layer_mt:setAABB(id, minx, miny, maxx, maxy)
    assert(not self._deleted, "Layer has been deleted")
    C.layer_set_AABB(self._handle, id, minx, miny, maxx, maxy)
end

function collision.layer_mt:setCapsule(id, ax, ay, bx, by, r)
    assert(not self._deleted, "Layer has been deleted")
    C.layer_set_Capsule(self._handle, id, ax, ay, bx, by, r)
end

function collision.layer_mt:remove(id)
    assert(not self._deleted, "Layer has been deleted")
    C.layer_remove(self._handle, id)
end

function collision.layer_mt:getCollisions(id)
    assert(not self._deleted, "Layer has been deleted")
    local result = C.layer_getCollisions(self._handle, id)
    if result.data == nil then
        return nil, 0
    end
    local ids = ffi.cast("uint32_t*", result.data)
    return ids, result.size
end

function collision.layer_mt:getCollisionsBatch(ids)
    assert(not self._deleted, "Layer has been deleted")
    local num_ids = #ids
    local id_array = ffi.new("uint32_t[?]", num_ids)
    for i = 1, num_ids do
        id_array[i-1] = ids[i]
    end
    local result = C.layer_getCollisionsBatch(self._handle, id_array, num_ids)
    if result.data == nil then
        return nil, 0
    end
    local ids_out = ffi.cast("uint32_t*", result.data)
    return ids_out, result.size
end

function collision.layer_mt:getManifolds(id)
    assert(not self._deleted, "Layer has been deleted")
    local result = C.layer_getManifolds(self._handle, id)
    if result.data == nil then
        return nil, 0
    end
    local data = ffi.cast("float*", result.data)
    return data, result.size / 5  -- 5 floats per manifold
end

function collision.layer_mt:queryPoint(x, y)
    assert(not self._deleted, "Layer has been deleted")
    local result = C.layer_queryPoint(self._handle, x, y)
    if result.data == nil then
        return nil, 0
    end
    local ids = ffi.cast("uint32_t*", result.data)
    return ids, result.size
end

function collision.layer_mt:queryAABB(minx, miny, maxx, maxy)
    assert(not self._deleted, "Layer has been deleted")
    local result = C.layer_queryAABB(self._handle, minx, miny, maxx, maxy)
    if result.data == nil then
        return nil, 0
    end
    local ids = ffi.cast("uint32_t*", result.data)
    return ids, result.size
end

function collision.layer_mt:resetBuffers()
    assert(not self._deleted, "Layer has been deleted")
    C.layer_reset_buffers(self._handle)
end

-- Garbage collection
collision.layer_mt.__gc = collision.layer_mt.delete

-- Convenience functions (backwards compatibility)
function collision.newLayer(...)
    return collision.new(...)
end

-- Export the raw C interface for advanced users
collision.C = C

return collision