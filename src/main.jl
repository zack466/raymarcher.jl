include("console.jl")
include("marching.jl")
using Dates

# non-blocking way of testing for Enter
function press_enter()
    rx = Channel(1)
    @async put!(rx, readline())
    return rx
end

function render()
    height, width = 45, 130
    buf = Array{Char, 1}(undef, height * width) # [ width | width | width ]
    enter = press_enter()

    time = 0.0

    while true
        t1 = Dates.now()

        if isready(enter)
            break
        end

        raymarch!(buf, height, width, time)

        show_buffer(buf, height, width)
        move_cursor_up(height)

        t2 = Dates.now()
        while (t2 - t1).value < 16 # 16 ms ≈ 60fps
            t2 = Dates.now()
        end
        time += (t2 - t1).value / 1000.0
    end
end

render()
