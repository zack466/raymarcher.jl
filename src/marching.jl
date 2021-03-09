using LinearAlgebra
include("console.jl")

# const PIXEL_SHADES = reverse("\$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,\"^`'. ")
const PIXEL_SHADES = " .:-=+*#%@"

function normalized(vec::Vector)
    return vec ./ norm(vec)
end

function sdf_union(a::Float32, b::Float32)
    min(a, b)
end

abstract type SceneObject end;

struct Scene
    objects::Vector{SceneObject}
end

function sdf(scene::Scene, pos::Vector{Float32})
    res = 9999.9f0
    for obj in scene.objects
        res = min(sdf(obj, pos))
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

            sphere = Sphere([0.0, 0.0, 0.0], 0.4)
            maxdist = 9999.9
            pixel = PIXEL_SHADES[1]
            for _ in 1:20
                if any(map(x -> x > maxdist, ray))
                    break
                end
                dist = sdf(sphere, pos)
                if dist < 1e-6
                    pixel = shade(pos, x->sdf(sphere, x), time)
                    break
                end
                pos += ray * dist
            end
            screen.buf[(y-1)*screen.width + x] = pixel
        end
    end
end
