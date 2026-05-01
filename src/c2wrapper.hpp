
#pragma once

#define CUTE_C2_IMPLEMENTATION
#include "cute_c2.h"

#include <optional>
#include <variant>

namespace c2w {
// Some alias

using Circle = c2Circle;
using AABB = c2AABB;
using Capsule = c2Capsule;
using Manifold = c2Manifold;
using Ray = c2Ray;
using Shape = std::variant<Circle, AABB, Capsule>;

struct Rayhit {
  float distance;
  c2v n;
  c2v point;
};

// Collision manifold overloads

std::optional<Manifold> collision_manifold(const Circle &A, const Circle &B) {
  Manifold M;
  c2CircletoCircleManifold(A, B, &M);
  if (M.count == 0)
    return {};
  return M;
}

std::optional<Manifold> collision_manifold(const Circle &A, const AABB &B) {
  Manifold M;
  c2CircletoAABBManifold(A, B, &M);
  if (M.count == 0)
    return {};
  return M;
}

std::optional<Manifold> collision_manifold(const AABB &A, const Circle &B) {
  Manifold M;
  c2CircletoAABBManifold(B, A, &M);
  if (M.count == 0)
    return {};
  M.n = c2Mulvs(M.n, -1.0);
  return M;
}

std::optional<Manifold> collision_manifold(const AABB &A, const AABB &B) {
  Manifold M;
  c2AABBtoAABBManifold(A, B, &M);
  if (M.count == 0)
    return {};
  return M;
}

std::optional<Manifold> collision_manifold(const Circle &A, const Capsule &B) {
  Manifold M;
  c2CircletoCapsuleManifold(A, B, &M);
  if (M.count == 0)
    return {};
  return M;
}

std::optional<Manifold> collision_manifold(const Capsule &A, const Circle &B) {
  Manifold M;
  c2CircletoCapsuleManifold(B, A, &M);
  if (M.count == 0)
    return {};
  M.n = c2Mulvs(M.n, -1.0);
  return M;
}

std::optional<Manifold> collision_manifold(const Capsule &A, const Capsule &B) {
  Manifold M;
  c2CapsuletoCapsuleManifold(A, B, &M);
  if (M.count == 0)
    return {};
  return M;
}

std::optional<Manifold> collision_manifold(const AABB &A, const Capsule &B) {
  Manifold M;
  c2AABBtoCapsuleManifold(A, B, &M);
  if (M.count == 0)
    return {};
  return M;
}

std::optional<Manifold> collision_manifold(const Capsule &A, const AABB &B) {
  Manifold M;
  c2AABBtoCapsuleManifold(B, A, &M);
  if (M.count == 0)
    return {};
  M.n = c2Mulvs(M.n, -1.0);
  return M;
}

// Raycast overloads

std::optional<Rayhit> raycast(const Ray &r, const Circle &A) {
  c2Raycast rc;
  if (c2RaytoCircle(r, A, &rc) == 0) {
    return {};
  };
  return Rayhit{rc.t, rc.n, c2Impact(r, rc.t)};
}

std::optional<Rayhit> raycast(const Ray &r, const AABB &A) {
  c2Raycast rc;
  if (c2RaytoAABB(r, A, &rc) == 0) {
    return {};
  };
  return Rayhit{rc.t, rc.n, c2Impact(r, rc.t)};
}

std::optional<Rayhit> raycast(const Ray &r, const Capsule &A) {
  c2Raycast rc;
  if (c2RaytoCapsule(r, A, &rc) == 0) {
    return {};
  };
  return Rayhit{rc.t, rc.n, c2Impact(r, rc.t)};
}

// Collision check overloads

bool collision_check(const Circle &A, const Circle &B) {
  return c2CircletoCircle(A, B);
}

bool collision_check(const Circle &A, const AABB &B) {
  return c2CircletoAABB(A, B);
}

bool collision_check(const AABB &A, const Circle &B) {
  return c2CircletoAABB(B, A);
}

bool collision_check(const AABB &A, const AABB &B) {
  return c2AABBtoAABB(A, B);
}

bool collision_check(const Circle &A, const Capsule &B) {
  return c2CircletoCapsule(A, B);
}

bool collision_check(const Capsule &A, const Circle &B) {
  return c2CircletoCapsule(B, A);
}

bool collision_check(const Capsule &A, const Capsule &B) {
  return c2CapsuletoCapsule(A, B);
}

bool collision_check(const AABB &A, const Capsule &B) {
  return c2AABBtoCapsule(A, B);
}

bool collision_check(const Capsule &A, const AABB &B) {
  return c2AABBtoCapsule(B, A);
}

// Variant dispatch functions

std::optional<Manifold> collision_manifold(const Shape &A, const Shape &B) {
  return std::visit(
      [&](const auto &A, const auto &B) -> std::optional<Manifold> {
        return collision_manifold(A, B);
      },
      A, B);
}

bool collision_check(const Shape &A, const Shape &B) {
  return std::visit(
      [&](const auto &A, const auto &B) -> bool {
        return collision_check(A, B);
      },
      A, B);
}
std::optional<Rayhit> raycast(const Ray &r, const Shape &A) {
  return std::visit(
      [&](const auto &A) -> std::optional<Rayhit> { return raycast(r, A); }, A);
}
} // namespace c2w
