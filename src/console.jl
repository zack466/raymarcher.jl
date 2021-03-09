struct Screen
    height
    width
    buf::Array{Char, 1}
end

function cls()
    print(stdout, "\033[J")
end

function move_cursor_up(n_lines)
    print(stdout, "\033[$(n_lines)A")
end

function show_buffer(buf, height, width)
    for row in [buf[(i-1)*width + 1:i*width] for i in 1:height]
        println(join(row))
    end
end
