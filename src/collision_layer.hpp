#pragma once

#include "broadphase_grid.hpp"
#include "c2aabbgetter.hpp"
#include "c2wrapper.hpp"

class CollisionLayer {
 public:
  CollisionLayer(float cell_size)
      : cell_size_(cell_size), grid_(BroadphaseGrid(cell_size)) {};

  void setCircle(uint id, float x, float y, float r) {
    shapes_[id] = c2w::Circle{c2v{x, y}, r};
    updateGridEntry(id);
  }

  void setAABB(uint id, float minx, float miny, float maxx, float maxy) {
    shapes_[id] = c2w::AABB{.min = {minx, miny}, .max = {maxx, maxy}};
    updateGridEntry(id);
  }

  void setCapsule(uint id, float ax, float ay, float bx, float by, float r) {
    shapes_[id] = c2w::Capsule{.a = {ax, ay}, .b = {bx, by}, .r = r};
    updateGridEntry(id);
  }

  std::vector<uint> &getCollisions(uint A) {
    id_out.clear();
    auto shape_it = shapes_.find(A);
    if (shape_it == shapes_.end()) {
      return id_out;
    }
    auto &shape = shape_it->second;
    for (uint B : grid_.query(A)) {
      if (B == A)
        continue; // ignore self
      auto &otherShape = shapes_[B];
      if (c2w::collision_check(shape, otherShape)) {
        id_out.push_back(B);
      }
    }
    return id_out;
  }

  bool has(uint A) { return shapes_.find(A) != shapes_.end(); }

  void remove(uint id) {
    shapes_.erase(id);
    grid_.remove(id);
  }

  std::optional<c2w::Manifold> getManifold(uint A, uint B) {
    return c2w::collision_manifold(shapes_[A], shapes_[B]);
  }
  std::vector<c2w::Manifold> &getAllManifolds(uint A) {
    manifold_out.clear();
    for (uint B : getCollisions(A)) {
      manifold_out.push_back(getManifold(A, B).value());
    }
    return manifold_out;
  }

  // Expose shapes for point queries
  const std::unordered_map<uint, c2w::Shape>& getShapes() const {
    return shapes_;
  }

  // Point query - test point against all shapes (read-only)
  std::vector<uint>& queryPoint(float x, float y) {
    point_query_out.clear();
    c2w::Circle point_circle{c2v{x, y}, 0.0f};
    for (const auto& [id, shape] : shapes_) {
      if (c2w::collision_check(point_circle, shape)) {
        point_query_out.push_back(id);
      }
    }
    return point_query_out;
  }

  // AABB query - test AABB against broadphase (read-only)
  std::vector<uint>& queryAABB(const BroadphaseGrid::AABB &aabb) {
    aabb_query_out.clear();
    auto &ids = grid_.queryAABB(aabb);
    aabb_query_out.insert(aabb_query_out.end(), ids.begin(), ids.end());
    return aabb_query_out;
  }

 private:
  std::vector<uint> id_out;
  std::vector<c2w::Manifold> manifold_out;
  std::vector<uint> point_query_out;
  std::vector<uint> aabb_query_out;
  float cell_size_;
  BroadphaseGrid grid_;
  std::unordered_map<uint, c2w::Shape> shapes_;

  void updateGridEntry(uint id) { grid_.update(id, getAABBc2(shapes_[id])); }
};
