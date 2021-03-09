# with inspiration from https://ch-st.de/its-ray-marching-march/

using LinearAlgebra
include("console.jl")

# const PIXEL_SHADES = reverse("\$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,\"^`'. ")
const PIXEL_SHADES = " .:-=+*#%@"

function normalized(vec::Vector)
    return vec ./ norm(vec)
end

function rotate_y(theta::Float32)
    c = cos(theta); s = sin(theta)
    [
        c  0.0  s  0.0;
        0.0  1.0  0.0  0.0;
        (-s)  0.0  c  0.0;
        0.0  0.0  0.0  1.0;
    ]
end

abstract type SceneObject end;

function sdf_rotate(obj::SceneObject, pos::Vector{Float32}, theta::Float32)
    newpos::Array{Float32, 1} = (inv(rotate_y(theta)) * vcat(pos, 1.0))[1:3]
    sdf(obj, newpos)
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
    norm(pos - sphere.center) - sphere.radius
end

struct Box <: SceneObject
    b::Vector{Float32}
end

function sdf(box::Box, pos::Vector{Float32})
    @assert length(pos) == 3
    q = abs.(pos) - box.b
    norm(max.(q, 0.0)) + min(max(q[1], q[2], q[3]), 0.0)
end

function shade(pos::Vector{Float32}, sdf::Function, time::Float32)
    light::Vector{Float32} = [50.0 * sin(time), 20.0, 50.0 * cos(time)]
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
    for y in 1:screen.height
        for x in 1:screen.width
            pos::Vector{Float32} = [0.0, 0.0, -3.0]
            target = [
                x / screen.width - 0.5,
                (y / screen.height - 0.5) * (screen.height / screen.width) * 1.8,
                -1.5,
               ]
            ray = normalized(target - pos)

            # sphere = Sphere([0.0, 0.0, 0.0], 0.4)
            box = Box([0.2, 0.2, 0.2])
            maxdist = 9999.9
            pixel = PIXEL_SHADES[1]
            # total_sdf = x -> sdf(box, x)
            total_sdf = x -> sdf_rotate(box, x, 1.4f0)
            for _ in 1:20
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
