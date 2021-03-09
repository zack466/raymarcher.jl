include("console.jl")
include("marching.jl")


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

    time = 0.0f0

    while true
        if isready(enter)
            break
        end

        raymarch!(screen, time)

        show_buffer(screen.buf, screen.height, screen.width)
        move_cursor_up(screen.height)
        time += 0.07f0
        sleep(0.016)
    end
end

main()
