const std = @import("std");
const raylib = @import("raylib");
const rlib_math = @import("raylib-math");
// const rlgl = @import("rlgl");

const clamp = std.math.clamp;

const vec2f = raylib.Vector2;

const radius: f32 = 10.0;
const radius_int: u32 = @as(u32, radius);

const screenWidth = 1080;
const screenHeight = 720;

const ZERO_VECTOR = vec2f.init(0, 0);

const mouseAngle = normalMouseAngle;

var dprng = std.rand.DefaultPrng.init(0);
const rand = dprng.random();

const CollisionTup = struct {
    bool: bool,
    point: vec2f,
    rec_idx: usize,
};

const Screen = enum {
    MainMenu,
    Game,
    EndScreen,
};

fn clearEnemyList(enemyList: *std.ArrayList(raylib.Rectangle)) !void {
    enemyList.resize(0) catch @panic("Failed to clear enemy list");
}

fn normalMouseAngle(center: vec2f, mouse: vec2f) f32 {
    return std.math.atan2(mouse.y - center.y, mouse.x - center.x);
}

fn mirroredMouseAngle(center: vec2f, mouse: vec2f) f32 {
    return std.math.atan2(center.y - mouse.y, center.x - mouse.x);
}

fn calculateAimPathV(player: vec2f, mouse: vec2f) vec2f {
    const angle = mouseAngle(player, mouse);
    const cos_angle = std.math.cos(angle);
    const sin_angle = std.math.sin(angle);

    var max_dist_x: f32 = undefined;
    var max_dist_y: f32 = undefined;

    // check if the angle is positive or negative to determine the max distance
    // if negative, the max distance is the player's current position
    if (cos_angle > 0) {
        max_dist_x = @as(f32, @floatFromInt(screenWidth)) - player.x;
    } else {
        max_dist_x = -player.x;
    }

    if (sin_angle > 0) {
        max_dist_y = @as(f32, @floatFromInt(screenHeight)) - player.y;
    } else {
        max_dist_y = -player.y;
    }

    // refresh on geometry
    const max_dist = @min(max_dist_x / cos_angle, max_dist_y / sin_angle);

    const max_x = player.x + max_dist * cos_angle;
    const max_y = player.y + max_dist * sin_angle;

    return vec2f.init(max_x, max_y);
}

fn calculateAimLineV(player: vec2f, mouse: vec2f) vec2f {
    const angle = mouseAngle(player, mouse);
    const line_length = radius * 3; // Adjust this value to change the line length

    const end_x = player.x + line_length * std.math.cos(angle);
    const end_y = player.y + line_length * std.math.sin(angle);

    return vec2f.init(end_x, end_y);
}

fn spawnEnemy(missedShotCoords: vec2f, enemyList: *std.ArrayList(raylib.Rectangle)) !void {
    for (0..rand.intRangeAtMost(usize, 1, 5)) |_| {
        const offset = vec2f.init(rand.float(f32) * 10, rand.float(f32) * 10);
        const rec = raylib.Rectangle.init(missedShotCoords.x + offset.x, missedShotCoords.y + offset.y, 10, 10);
        try enemyList.append(rec);
    }
}

fn drawEnemies(enemyList: *std.ArrayList(raylib.Rectangle)) void {
    for (enemyList.items) |enemy| {
        raylib.drawRectangleRec(enemy, raylib.Color.red);
    }
}

fn updateEnemyPos(player: vec2f, enemyList: *std.ArrayList(raylib.Rectangle)) void {
    for (0..enemyList.items.len) |i| {
        const rec = enemyList.items[i];
        const originToPlayer = subtractVectors(player, ZERO_VECTOR);
        const originToEnemy = subtractVectors(vec2f.init(rec.x, rec.y), ZERO_VECTOR);
        const enemyToPlayer = subtractVectors(originToPlayer, originToEnemy);
        const normalized = normalizeVector(enemyToPlayer);
        enemyList.items[i] = raylib.Rectangle.init(rec.x + (normalized.x * 2), rec.y + (normalized.y * 2), rec.width, rec.height);
    }
}

fn subtractVectors(a: vec2f, b: vec2f) vec2f {
    return vec2f.init(a.x - b.x, a.y - b.y);
}

fn normalizeVector(v: vec2f) vec2f {
    const len = std.math.sqrt(v.x * v.x + v.y * v.y);
    return vec2f.init(v.x / len, v.y / len);
}

fn checkCollisionLineRec(enemyList: *std.ArrayList(raylib.Rectangle), line_start: vec2f, line_end: vec2f) CollisionTup {
    var tup = CollisionTup{ .bool = false, .point = undefined, .rec_idx = undefined };
    outer: for (enemyList.items, 0..) |rec, i| {
        var x: f32 = rec.x;
        while (x <= rec.x + rec.width) : (x += 1.0) {
            var y: f32 = rec.y;
            while (y <= rec.y + rec.height) : (y += 1.0) {
                const collision_point = vec2f.init(x, y);
                if (raylib.checkCollisionPointLine(collision_point, line_start, line_end, 1)) {
                    tup = CollisionTup{ .bool = true, .point = collision_point, .rec_idx = i };
                    break :outer;
                }
            }
        }
    }

    return tup;
}

fn checkCollisionEnemyPlayer(enemyList: *std.ArrayList(raylib.Rectangle), player: vec2f) bool {
    for (enemyList.items) |rec| {
        if (raylib.checkCollisionCircleRec(player, radius, rec)) {
            // raylib.drawText("DEATH!", 900, 10, 20, raylib.Color.red);
            return true;
        }
    }
    return false;
}

fn spawnInitialEnemies(enemyList: *std.ArrayList(raylib.Rectangle)) !void {
    for (0..8) |_| {
        const coords = vec2f.init(rand.float(f32) * 1080, rand.float(f32) * 720);
        const rec = raylib.Rectangle.init(coords.x, coords.y, 10, 10);
        try enemyList.append(rec);
    }
}

// fn showEndScreen(numCollisions: usize, allocator: std.mem.Allocator) !void {
//     raylib.beginDrawing();
//     defer raylib.endDrawing();
//
//     raylib.clearBackground(raylib.Color.white);
//     raylib.drawText("Game Over", 900, 10, 20, raylib.Color.red);
//     const deathStr = try std.fmt.allocPrintZ(allocator, "You hit: {d} rectangles", .{numCollisions});
//     raylib.drawText(deathStr, 900, 50, 20, raylib.Color.red);
// }

pub fn main() anyerror!void {
    raylib.initWindow(screenWidth, screenHeight, "Death is a Blessing concept test");
    defer raylib.closeWindow();

    var numCollisions: usize = 0;

    var ballPos = vec2f.init(screenWidth / 2, screenHeight / 2);
    var mousePos = vec2f.init(0, 0);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const test_alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    var enemyList: std.ArrayList(raylib.Rectangle) = std.ArrayList(raylib.Rectangle).init(gpa.allocator());
    defer enemyList.deinit();

    try spawnInitialEnemies(&enemyList);

    var currentScreen = Screen.MainMenu;
    // var frameCounter: usize = 0;
    raylib.setTargetFPS(60);

    while (!raylib.windowShouldClose()) {
        switch (currentScreen) {
            Screen.MainMenu => blk: {
                // frameCounter += 1;
                if (raylib.isKeyPressed(raylib.KeyboardKey.key_enter)) currentScreen = Screen.Game;
                break :blk;
            },
            Screen.Game => blk: {
                if (checkCollisionEnemyPlayer(&enemyList, ballPos)) currentScreen = Screen.EndScreen;
                break :blk;
            },
            Screen.EndScreen => blk: {
                if (raylib.isKeyPressed(raylib.KeyboardKey.key_enter)) {
                    currentScreen = Screen.MainMenu;
                    numCollisions = 0;
                    ballPos = vec2f.init(screenWidth / 2, screenHeight / 2);
                    try clearEnemyList(&enemyList);
                    try enemyList.append(raylib.Rectangle.init(900, 600, 30, 30));
                }
                break :blk;
            },
        }

        // draw
        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.hideCursor();

        switch (currentScreen) {
            Screen.MainMenu => blk: {
                raylib.clearBackground(raylib.Color.white);
                raylib.drawText("Press Enter to start", 10, 10, 20, raylib.Color.black);
                break :blk;
            },
            Screen.Game => blk: {
                // Get input and update
                if (ballPos.x >= screenWidth - radius_int) ballPos.x = screenWidth - radius_int;
                if (ballPos.x <= 0 + radius_int) ballPos.x = 0 + radius_int;
                if (ballPos.y >= screenHeight - radius_int) ballPos.y = screenHeight - radius_int;
                if (ballPos.y <= 0 + radius_int) ballPos.y = 0 + radius_int;
                if (raylib.isKeyDown(raylib.KeyboardKey.key_w)) ballPos.y -= 2.5;
                if (raylib.isKeyDown(raylib.KeyboardKey.key_a)) ballPos.x -= 2.5;
                if (raylib.isKeyDown(raylib.KeyboardKey.key_s)) ballPos.y += 2.5;
                if (raylib.isKeyDown(raylib.KeyboardKey.key_d)) ballPos.x += 2.5;

                mousePos = raylib.getMousePosition();
                mousePos.x = @as(f32, @floatFromInt(raylib.getMouseX()));
                mousePos.y = @as(f32, @floatFromInt(raylib.getMouseY()));

                const string = try std.fmt.allocPrintZ(test_alloc, "move da ball, x: {d}, y: {d}, #. enemies: {d}, hits: {d}", .{ ballPos.x, ballPos.y, enemyList.items.len, numCollisions });
                defer test_alloc.free(string);

                const aimPath = calculateAimPathV(ballPos, mousePos);
                const aimLine = calculateAimLineV(ballPos, mousePos);

                raylib.clearBackground(raylib.Color.white);
                raylib.drawText(string, 10, 10, 20, raylib.Color.black);
                raylib.drawCircleV(ballPos, radius, raylib.Color.green);
                raylib.drawLineV(ballPos, aimLine, raylib.Color.gray);

                drawEnemies(&enemyList);
                updateEnemyPos(ballPos, &enemyList);

                // check for collision between shot path and target
                if (raylib.isMouseButtonDown(raylib.MouseButton.mouse_button_left)) {
                    const collision = checkCollisionLineRec(&enemyList, ballPos, aimPath);
                    if (collision.bool == true) {
                        numCollisions += 1;
                        raylib.drawText("COLLISION!", 900, 10, 20, raylib.Color.green);
                        raylib.drawLineV(ballPos, collision.point, raylib.Color.dark_green);
                        _ = enemyList.orderedRemove(collision.rec_idx);
                    } else {
                        raylib.drawLineV(ballPos, aimPath, raylib.Color.gray);
                        try spawnEnemy(aimPath, &enemyList);
                    }
                }
                break :blk;
            },
            Screen.EndScreen => blk: {
                const deathStr = try std.fmt.allocPrintZ(test_alloc, "You hit: {d} rectangles", .{numCollisions});
                defer test_alloc.free(deathStr);
                raylib.clearBackground(raylib.Color.white);
                raylib.drawText("Game Over", screenWidth / 2 - 20, screenHeight / 2 - 25, 20, raylib.Color.red);
                raylib.drawText(deathStr, screenWidth / 2 - 20, screenHeight / 2, 20, raylib.Color.red);
                break :blk;
            },
        }
    }
}
