include("console.jl")
include("marching.jl")
using Dates

# non-blocking way of testing for Enter
function press_enter()
    rx = Channel(1)
    @async put!(rx, readline())
    return rx
end

function main()
    height, width = 20, 40
    buf = Array{Char, 1}(undef, height * width) # [ width | width | width ]
    screen = Screen(height, width, buf)
    enter = press_enter()

    time::Float32 = 0.0f0

    while true
        t1 = Dates.now()

        if isready(enter)
            break
        end

        raymarch!(screen, time)

        show_buffer(screen.buf, screen.height, screen.width)
        move_cursor_up(screen.height)

        t2 = Dates.now()
        while (t2 - t1).value < 16
            t2 = Dates.now()
        end
        time += (t2 - t1).value / 1000.0f0
    end
end

main()
