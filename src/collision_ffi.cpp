#include "collision_layer.hpp"
#include <sys/types.h>
#include <cstring>

extern "C" {
typedef struct {
  void *data;
  size_t size;
  size_t element_size;
} ArrayHandle;

// Preallocated buffer for collision results
typedef struct {
  uint32_t *data;
  size_t capacity;
  size_t count;
} CollisionBuffer;

// Preallocated buffer for manifold results  
typedef struct {
  float *data;  // packed: normal_x, normal_y, contact_x, contact_y, depth (5 floats per manifold)
  size_t capacity;
  size_t count;
} ManifoldBuffer;

// Layer handle with preallocated buffers
typedef struct {
  CollisionLayer *layer;
  CollisionBuffer *collision_buffer;
  ManifoldBuffer *manifold_buffer;
} LayerHandle;

// Create a layer with preallocated buffer sizes
LayerHandle* layer_new_with_buffers(float cell_size, size_t max_collisions, size_t max_manifolds) {
  LayerHandle *handle = new LayerHandle();
  handle->layer = new CollisionLayer(cell_size);
  
  // Preallocate collision buffer
  handle->collision_buffer = new CollisionBuffer();
  handle->collision_buffer->data = new uint32_t[max_collisions];
  handle->collision_buffer->capacity = max_collisions;
  handle->collision_buffer->count = 0;
  
  // Preallocate manifold buffer (5 floats per manifold)
  handle->manifold_buffer = new ManifoldBuffer();
  handle->manifold_buffer->data = new float[max_manifolds * 5];
  handle->manifold_buffer->capacity = max_manifolds;
  handle->manifold_buffer->count = 0;
  
  return handle;
}

LayerHandle* layer_new(float cell_size) {
  return layer_new_with_buffers(cell_size, 1024, 512);
}

void layer_delete(LayerHandle *handle) {
  if (!handle) return;
  delete handle->layer;
  delete[] handle->collision_buffer->data;
  delete handle->collision_buffer;
  delete[] handle->manifold_buffer->data;
  delete handle->manifold_buffer;
  delete handle;
}

void layer_reset_buffers(LayerHandle *handle) {
  if (!handle) return;
  handle->collision_buffer->count = 0;
  handle->manifold_buffer->count = 0;
}

void layer_set_circle(LayerHandle *handle, uint id, float x, float y, float r) {
  if (!handle) return;
  handle->layer->setCircle(id, x, y, r);
}

void layer_set_AABB(LayerHandle *handle, uint id, float minx, float miny,
                    float maxx, float maxy) {
  if (!handle) return;
  handle->layer->setAABB(id, minx, miny, maxx, maxy);
}

void layer_set_Capsule(LayerHandle *handle, uint id, float ax, float ay,
                       float bx, float by, float r) {
  if (!handle) return;
  handle->layer->setCapsule(id, ax, ay, bx, by, r);
}

void layer_remove(LayerHandle *handle, uint id) {
  if (!handle) return;
  handle->layer->remove(id);
}

// Get collisions into preallocated buffer
ArrayHandle layer_getCollisions(LayerHandle *handle, uint id) {
  ArrayHandle result = {nullptr, 0, sizeof(uint32_t)};
  if (!handle) return result;
  
  auto v = handle->layer->getCollisions(id);
  size_t count = v.size();
  
  // Cap at buffer capacity
  if (count > handle->collision_buffer->capacity) {
    count = handle->collision_buffer->capacity;
  }
  
  memcpy(handle->collision_buffer->data, v.data(), count * sizeof(uint32_t));
  handle->collision_buffer->count = count;
  
  result.data = handle->collision_buffer->data;
  result.size = count;
  return result;
}

// Batch get collisions for multiple IDs
ArrayHandle layer_getCollisionsBatch(LayerHandle *handle, uint *ids, size_t num_ids) {
  ArrayHandle result = {nullptr, 0, sizeof(uint32_t)};
  if (!handle || !ids || num_ids == 0) return result;
  
  size_t total = 0;
  uint32_t *buffer = handle->collision_buffer->data;
  size_t capacity = handle->collision_buffer->capacity;
  
  for (size_t i = 0; i < num_ids; i++) {
    auto v = handle->layer->getCollisions(ids[i]);
    for (uint32_t id : v) {
      if (total < capacity) {
        buffer[total++] = id;
      }
    }
  }
  
  handle->collision_buffer->count = total;
  result.data = buffer;
  result.size = total;
  return result;
}

// Get manifolds into preallocated buffer
ArrayHandle layer_getManifolds(LayerHandle *handle, uint id) {
  ArrayHandle result = {nullptr, 0, sizeof(float)};
  if (!handle) return result;
  
  auto manifolds = handle->layer->getAllManifolds(id);
  size_t count = manifolds.size();
  
  // Cap at buffer capacity
  if (count > handle->manifold_buffer->capacity) {
    count = handle->manifold_buffer->capacity;
  }
  
  // Pack manifold data: normal_x, normal_y, contact_x, contact_y, depth per manifold
  float *data = handle->manifold_buffer->data;
  for (size_t i = 0; i < count; i++) {
    const auto& m = manifolds[i];
    size_t offset = i * 5;
    data[offset + 0] = m.n.x;
    data[offset + 1] = m.n.y;
    data[offset + 2] = m.contact_points[0].x;
    data[offset + 3] = m.contact_points[0].y;
    data[offset + 4] = m.depths[0];
  }
  
  handle->manifold_buffer->count = count;
  result.data = handle->manifold_buffer->data;
  result.size = count * 5;  // 5 floats per manifold
  return result;
}

// Point query - test point against all shapes (read-only, no layer modification)
ArrayHandle layer_queryPoint(LayerHandle *handle, float x, float y) {
  ArrayHandle result = {nullptr, 0, sizeof(uint32_t)};
  if (!handle) return result;
  
  auto &ids = handle->layer->queryPoint(x, y);
  uint32_t *buffer = handle->collision_buffer->data;
  size_t capacity = handle->collision_buffer->capacity;
  size_t count = ids.size();
  
  if (count > capacity) {
    count = capacity;
  }
  
  memcpy(buffer, ids.data(), count * sizeof(uint32_t));
  handle->collision_buffer->count = count;
  
  result.data = buffer;
  result.size = count;
  return result;
}

// AABB query - test AABB against broadphase (read-only)
ArrayHandle layer_queryAABB(LayerHandle *handle, float minx, float miny, float maxx, float maxy) {
  ArrayHandle result = {nullptr, 0, sizeof(uint32_t)};
  if (!handle) return result;
  
  BroadphaseGrid::AABB query_aabb{minx, miny, maxx, maxy};
  auto &ids = handle->layer->queryAABB(query_aabb);
  
  uint32_t *buffer = handle->collision_buffer->data;
  size_t capacity = handle->collision_buffer->capacity;
  size_t count = ids.size();
  
  if (count > capacity) {
    count = capacity;
  }
  
  memcpy(buffer, ids.data(), count * sizeof(uint32_t));
  handle->collision_buffer->count = count;
  
  result.data = buffer;
  result.size = count;
  return result;
}

// Get buffer pointers for direct FFI access
CollisionBuffer* layer_getCollisionBuffer(LayerHandle *handle) {
  return handle ? handle->collision_buffer : nullptr;
}

ManifoldBuffer* layer_getManifoldBuffer(LayerHandle *handle) {
  return handle ? handle->manifold_buffer : nullptr;
}

// Get buffer capacity
size_t layer_getCollisionCapacity(LayerHandle *handle) {
  return handle ? handle->collision_buffer->capacity : 0;
}

size_t layer_getManifoldCapacity(LayerHandle *handle) {
  return handle ? handle->manifold_buffer->capacity : 0;
}

}