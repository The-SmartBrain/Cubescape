def calc_occupied_cells(a, b, origin):

    m = [origin[0]-a/2, origin[1]+b/2]
    g = [origin[0]+a/2, origin[1]-b/2]

    tiles = []

    x = m[0]+0.5
    y = m[1]-0.5

    while y >= g[1]:
        while x <= g[0]:
            tiles.append([x, y])
            x += 1
        x = m[0] + 0.5
        y -= 1

    print(tiles, "\n")


calc_occupied_cells(1, 1, [0, 0])
calc_occupied_cells(1, 2, [0, 0.5])
calc_occupied_cells(2, 1, [0.5, 0])
calc_occupied_cells(2, 2, [0.5, 0.5])
calc_occupied_cells(3, 1, [0, 0])
calc_occupied_cells(3, 3, [0, 0])
