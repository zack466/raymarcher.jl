# with inspiration from https://ch-st.de/its-ray-marching-march/
# TODO: implement small static arrays for speedups
# TODO: improve speed of rot matrices. How to prevent too many array allocations?
# TODO: check if jl_apply_generic is a performance issue or not
# TODO: add more sdf functions, stabilize sdf API (functional, eager, etc)
# TODO: better way of handing animation/state (currently just passing time as a parameter)
# TODO: get scene struct set up for easily displaying multiple things
# TODO: autodiff normal vector if we get speedups
# TODO: add tests for easy benchmarking
# TODO: improve package structure
# TODO: deal with hcat/vcat slowness
# TODO: float32 vs float64 speed? Just replace everything with float64 probably
# TODO: dithering for better-looking ascii output
# TODO: improve camera implmentation, allow for movement/rotation

using LinearAlgebra
using Memoize
using StaticArrays
include("console.jl")

# const PIXEL_SHADES = reverse("\$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,\"^`'. ")
const PIXEL_SHADES = " .:-=+*#%@"

abstract type SceneObject end;

function normalized(vec::Vector)
    return vec ./ norm(vec)
end

@memoize function rot_z(theta::Float32)
    c = cos(theta); s = sin(theta)
    [
        1.0  0.0  0.0  0.0;
        0.0  c  (-s)  0.0;
        0.0  s  c  0.0;
        0.0  0.0  0.0  1.0;
    ]
end

@memoize function rot_y(theta::Float32)
    c = cos(theta); s = sin(theta)
    [
        c  0.0  s  0.0;
        0.0  1.0  0.0  0.0;
        (-s)  0.0  c  0.0;
        0.0  0.0  0.0  1.0;
    ]
end

@memoize function rot_x(theta::Float32)
    c = cos(theta); s = sin(theta)
    [
     1.0 0.0 0.0 0.0;
     0.0 c (-s) 0.0;
     0.0 s c 0.0;
     0.0 0.0 0.0 1.0;
    ]
end

@memoize function total_rot(theta_x::Float32 = 0.0f0, theta_y::Float32 = 0.0f0, theta_z::Float32 = 0.0f0)
    inv(rot_z(theta_z) * rot_y(theta_y) * rot_x(theta_x))
end

function sdf_rotate(obj::SceneObject, pos::Vector{Float32}, theta_x::Float32 = 0.0f0, theta_y::Float32 = 0.0f0, theta_z::Float32 = 0.0f0)
    rot_matrix::Array{Float32, 2} = total_rot(theta_x, theta_y, theta_z)
    newpos::Array{Float32, 1} = rot_matrix[1:3, 1:3] * pos
    sdf(obj, newpos)
end

function sdf_translate(obj::SceneObject, pos::Vector{Float32}, offset::Vector{Float32})
    sdf(obj, pos .- offset)
end

function sdf_union(a::Float32, b::Float32)
    min(a, b)
end

struct Scene
    objects::Vector{SceneObject}
end

function sdf(scene::Scene, pos::Vector{Float32})
    res = 9999.9f0
    for obj in scene.objects
        res = min(res, sdf(obj, pos))
    end
    res
end


struct Sphere <: SceneObject
    center::Vector{Float32}
    radius::Float32
end

function sdf(sphere::Sphere, pos::Vector{Float32})
    norm(pos .- sphere.center) - sphere.radius
end

struct Box <: SceneObject
    b::Vector{Float32}
end

function sdf(box::Box, pos::Vector{Float32})
    @assert length(pos) == 3
    q = abs.(pos) .- box.b
    norm(max.(q, 0.0)) + min(max(q[1], q[2], q[3]), 0.0)
end

function shade(pos::Vector{Float32}, sdf::Function, time::Float32)
    light::Vector{Float32} = [50.0 * sin(time), 20.0, 50.0 * cos(time)]
    # light::Vector{Float32} = [25.0, 20.0, 25.0]

    light = normalized(light)

    dt = 1e-6;
    current_val = sdf(pos)

    # gradient of sdf w.r.t. x,y,z ≈ surface normal
    x::Vector{Float32} = [pos[1] + dt, pos[2], pos[3]]
    dx = sdf(x) - current_val;
    y::Vector{Float32} = [pos[1], pos[2] + dt, pos[3]]
    dy = sdf(y) - current_val;
    z::Vector{Float32} = [pos[1], pos[2], pos[3] + dt]
    dz = sdf(z) - current_val;

    normal = [
              (dx - pos[1]) / dt,
              (dy - pos[2]) / dt,
              (dz - pos[3]) / dt,
             ]

    if norm(normal) < 1e-9
        return PIXEL_SHADES[0];
    end
    
    normal = normalized(normal)

    diffuse = dot(light, normal)
    diffuse = (diffuse + 1.0) / 2.0 * length(PIXEL_SHADES);

    return PIXEL_SHADES[1 + Int(floor(diffuse)) % length(PIXEL_SHADES)];
end

function raymarch!(screen::Screen, time::Float32) 
    # sphere = Sphere([0.0, 0.0, 0.0],0.4)
    box = Box([0.2, 0.2, 0.2])
    # total_sdf = x -> sdf_translate(box, x, [0.0f0, 0.3f0, 0.0f0])
    # total_sdf = x -> sdf(sphere, x - [0.0f0, sin(time) * 0.5f0, 0.05f0])
    total_sdf = x -> sdf_rotate(box, x, 0.0f0, 0.8f0, 0.5f0)

    for y in 1:screen.height
        for x in 1:screen.width
            pos::Vector{Float32} = [0.0, -0.1, -3.0]
            target = [
                x / screen.width - 0.5,
                (y / screen.height - 0.5) * (screen.height / screen.width) * 1.8,
                -1.5,
               ]
            ray = normalized(target .- pos)

            maxdist = 100.0
            pixel = PIXEL_SHADES[1]
            
            for _ in 1:30
                if any(map(x -> x > maxdist, ray))
                    break
                end
                dist = total_sdf(pos)
                if dist < 1e-6
                    pixel = shade(pos, total_sdf, time)
                    break
                end
                pos += ray * dist
            end
            screen.buf[(y-1)*screen.width + x] = pixel
        end
    end
end
