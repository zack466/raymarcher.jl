# with inspiration from https://ch-st.de/its-ray-marching-march/
# TODO: improve speed of rot matrices. How to prevent too many array allocations? or pre-allocation?
# TODO: check if jl_apply_generic is a performance issue or not
# TODO: add more sdf functions, stabilize sdf API
# TODO: better way of handing animation/state (currently just passing time as a parameter)
# TODO: add tests for easy benchmarking
# TODO: improve package structure
# TODO: improve camera implmentation, allow for movement/rotation
# TODO: add readme and gif example (and with credits/resources)
# TODO: use CUDA for computation? or some other way of parallelizing computation

using LinearAlgebra
using StaticArrays
using Random
using Base.Threads
include("sdf.jl")

# const PIXEL_SHADES = reverse("\$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,\"^`'. ")
const PIXEL_SHADES = " .:-~=+*o#%B@"
# const PIXEL_SHADES = " .:-=+*#%@"

function get_light_value(pos::Vec3, sdf::Function, time::Float64)
    # light::Vec3 = SA[50.0 * sin(time), 20.0, 50.0 * cos(time)]
    light::Vec3 = SA[5.0, 20.0, 5.0]

    light = normalized(light)

    dt = 1e-6;
    current_val = sdf(pos)

    # gradient of sdf w.r.t. x,y,z ≈ surface normal
    x::Vec3 = SA[pos[1] + dt, pos[2], pos[3]]
    dx = sdf(x) - current_val;
    y::Vec3 = SA[pos[1], pos[2] + dt, pos[3]]
    dy = sdf(y) - current_val;
    z::Vec3 = SA[pos[1], pos[2], pos[3] + dt]
    dz = sdf(z) - current_val;

    normal = SA[
              (dx - pos[1]) / dt,
              (dy - pos[2]) / dt,
              (dz - pos[3]) / dt,
             ]

    # if calculation fails...?
    if norm(normal) < 1e-9
        return PIXEL_SHADES[1];
    end
    
    normal = normalized(normal)

    diffuse = dot(light, normal) # ranges from -1 to 1
    diffuse = (diffuse + 1.0) / 2.0 # ranges from 0 to 1

    # diffuse += rand() - 0.1 # noise from -0.5 to 0.5
    # diffuse = clamp(diffuse, 0.0, length(PIXEL_SHADES) - 1)

    return diffuse
    # return PIXEL_SHADES[1 + Int(floor(diffuse)) % length(PIXEL_SHADES)];
end

function lighting(height::Int64, width::Int64, time::Float64)
    box = Box(SA[0.4, 0.2, 0.2])
    sphere = Sphere(SA[0.0, 0.0, 0.0], 0.2)
    # box = Sphere([0.0, 0.0, 0.0], 0.2)
    total_sdf = pos -> min(sdf(box, pos |> sdf_translate(SA[0.0, 0.0, 0.0]) |> sdf_rotate(0.4, 2pi*rem(time/2.4, 1.0, RoundNearest), 0.4)),
                           sdf(sphere, pos |> sdf_translate(SA[sin(time), 0.0, 0.0])))
    # total_sdf = pos -> sdf(box, pos |> sdf_rotate(0.4, 2pi*rem(time/2.4, 1.0, RoundNearest), 0.4))

    light_vals = Array{Float64, 1}(undef, height*width)
    Threads.@threads for xy in 1:height*width
        xy -= 1
        x = xy % width + 1
        y = Int(floor(xy / width)) + 1

        pos::Vec3 = SA[0.0, -0.1, -3.0]
        target = SA[
            x / width - 0.5,
            (y / height - 0.5) * (height / width) * 1.8,
            -1.5,
           ]
        ray = normalized(target .- pos)

        maxdist = 100.0
        light = 0.0

        for _ in 1:150
            if any(map(x -> x > maxdist, ray))
                break
            end
            dist = total_sdf(pos)
            if dist < 1e-6
                light = get_light_value(pos, total_sdf, time)
                break
            end
            pos += ray * dist
        end
        light_vals[(y-1)*width + x] = light # 0 to 1
        # light_vals[xy] = light # 0 to 1
    end
    light_vals
end

function raymarch!(buf::Array{Char, 1}, height::Int64, width::Int64, time::Float64) 
    # sphere = Sphere([0.0, 0.0, 0.0],0.4)
    # total_sdf = x -> sdf_translate(box, x, [0.0, 0.3, 0.0])
    # total_sdf = x -> sdf(sphere, x - [0.0, sin(time) * 0.5, 0.05])
    # total_sdf = x -> sdf_rotate(box, x, 0.0, 0.8, 0.5)
    # total_sdf = x -> sdf(sphere, x)
    # transformations = sdf_transform([
    #                                  sdf_translate(SA[0.0, 0.0, 0.0]),
    #                                  sdf_rotate(cos(time), sin(time), 0.5)
    #                                 ])
    
    light_mask = lighting(height, width, time) # actual ray-marching goes on here

    for y in 1:height, x in 1:width
        light = light_mask[(y-1)*width + x]

        light *= length(PIXEL_SHADES)
        pixel = PIXEL_SHADES[1 + Int(floor(light)) % length(PIXEL_SHADES)];
        buf[(y-1)*width + x] = pixel
    end
    
end


