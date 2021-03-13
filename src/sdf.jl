using StaticArrays
using LinearAlgebra

const Vec2 = SVector{2, Float64}
const Vec3 = SVector{3, Float64}
const Vec4 = SVector{4, Float64}

abstract type SceneObject end;

function normalized(vec::Vec3)
    return vec ./ norm(vec)
end

function rot_z(theta::Float64)
    c = cos(theta); s = sin(theta)
    SA[
        1.0  0.0  0.0  0.0;
        0.0  c  (-s)  0.0;
        0.0  s  c  0.0;
        0.0  0.0  0.0  1.0;
    ]
end

function rot_y(theta::Float64)
    c = cos(theta); s = sin(theta)
    SA[
        c  0.0  s  0.0;
        0.0  1.0  0.0  0.0;
        (-s)  0.0  c  0.0;
        0.0  0.0  0.0  1.0;
    ]
end

function rot_x(theta::Float64)
    c = cos(theta); s = sin(theta)
    SA[
     1.0 0.0 0.0 0.0;
     0.0 c (-s) 0.0;
     0.0 s c 0.0;
     0.0 0.0 0.0 1.0;
    ]
end

function total_rot(theta_x::Float64 = 0.0, theta_y::Float64 = 0.0, theta_z::Float64 = 0.0)
    rot_matrix = SA[1.0 0.0 0.0 0.0;
                    0.0 1.0 0.0 0.0;
                    0.0 0.0 1.0 0.0;
                    0.0 0.0 0.0 1.0]

    if theta_z != 0.0
        rot_matrix *= rot_z(theta_z)
    end
    if theta_y != 0.0
        rot_matrix *= rot_y(theta_y)
    end
    if theta_x != 0.0
        rot_matrix *= rot_x(theta_x)
    end
    inv(rot_matrix)
end

function sdf_rotate(theta_x::Float64 = 0.0, theta_y::Float64 = 0.0, theta_z::Float64 = 0.0)
    rot_matrix::SMatrix{4, 4, Float64} = total_rot(theta_x, theta_y, theta_z)
    function rotated(pos::Vec3)::Vec3
        rot_matrix[SA[1 5 9; 2 6 10; 3 7 11]] * pos
    end
end

function sdf_translate(offset::Vec3)
    function translated(pos::Vec3)
        pos .- offset
    end
end

function sdf_transform(transformations::Vector{Function})
    function transformed(pos::Vec3)
        for f in transformations
            pos = f(pos)
        end
        pos
    end
end

function sdf_union(sdf1::Float64, sdf2::Float64)
    min(sdf1, sdf2)
end

struct Scene
    objects::Vector{SceneObject}
end

function sdf(scene::Scene, pos::Vec3)
    res = 9999.9
    for obj in scene.objects
        res = min(res, sdf(obj, pos))
    end
    res
end

struct Sphere <: SceneObject
    center::Vec3
    radius::Float64
end

function sdf(sphere::Sphere, pos::Vec3)
    norm(pos .- sphere.center) - sphere.radius
end

struct Box <: SceneObject
    b::Vec3
end

function sdf(box::Box, pos::Vec3)
    q = abs.(pos) .- box.b
    norm(max.(q, 0.0)) .+ min(max(q[1], q[2], q[3]), 0.0)
end


