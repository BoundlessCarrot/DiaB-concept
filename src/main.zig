const std = @import("std");
const raylib = @import("raylib");
const rlib_math = @import("raylib-math");
// const rlgl = @import("rlgl");

const clamp = std.math.clamp;

const radius: f32 = 10.0;
const radius_int: u32 = @as(u32, radius);

const screenWidth = 1080;
const screenHeight = 720;

const CollisionTup = struct {
    bool: bool,
    point: raylib.Vector2,
    rec_idx: usize,
};

fn normalMouseAngle(center: raylib.Vector2, mouse: raylib.Vector2) f32 {
    return std.math.atan2(mouse.y - center.y, mouse.x - center.x);
}

fn mirroredMouseAngle(center: raylib.Vector2, mouse: raylib.Vector2) f32 {
    return std.math.atan2(center.y - mouse.y, center.x - mouse.x);
}

fn calulateLineToEdgeV(center: raylib.Vector2, mouse: raylib.Vector2) raylib.Vector2 {
    const angle = normalMouseAngle(center, mouse);
    const max_x = center.x + (screenWidth / 2) * std.math.cos(angle);
    const max_y = center.y + (screenWidth / 2) * std.math.sin(angle);
    return raylib.Vector2.init(max_x, max_y);
}

fn calculateAimLine(center: raylib.Vector2, mouse: raylib.Vector2) raylib.Vector2 {
    const max = calulateLineToEdgeV(center, mouse);
    const angle = normalMouseAngle(center, mouse);
    const diag_len = std.math.sqrt((max.x - center.x) * (max.x - center.x) + (max.y - center.y) * (max.y - center.y));
    const clamp_x = center.x + (screenWidth / 2) * std.math.cos(angle) / diag_len + 25;
    const clamp_y = center.y + (screenWidth / 2) * std.math.sin(angle) / diag_len + 25;
    return raylib.Vector2.init(clamp_x, clamp_y);
}

fn calculatePathEnemyToPlayer(player: raylib.Vector2, enemy: raylib.Vector2) raylib.Vector2 {
    const angle = normalMouseAngle(player, enemy);
    const x = player.x + (screenWidth / 2) * std.math.cos(angle);
    const y = player.y + (screenWidth / 2) * std.math.sin(angle);
    return raylib.Vector2.init(x, y);
}

fn spawnEnemy(missedShotCoords: raylib.Vector2, enemyList: *std.ArrayList(raylib.Rectangle)) !void {
    const rec = raylib.Rectangle.init(missedShotCoords.x, missedShotCoords.y, 30, 30);
    try enemyList.append(rec);
}

fn drawEnemies(enemyList: *std.ArrayList(raylib.Rectangle)) void {
    for (enemyList.items) |enemy| {
        raylib.drawRectangleRec(enemy, raylib.Color.red);
    }
}

// TODO: updating isn't working completely correctly
//  direction and speed are wrong
//  coords need to be clamped to stay on the screen
fn updateEnemyPos(player: raylib.Vector2, enemyList: *std.ArrayList(raylib.Rectangle)) void {
    for (0..enemyList.items.len) |i| {
        const rec = enemyList.items[i];
        const slope = ((player.y - rec.y) / 5) / ((player.x - rec.x) / 5);
        // _ = @constCast(&enemyList.items[i]);
        enemyList.items[i] = raylib.Rectangle.init(rec.x - slope, rec.y - slope, rec.width, rec.height);
    }
}

fn checkCollisionLineRec(enemyList: *std.ArrayList(raylib.Rectangle), line_start: raylib.Vector2, line_end: raylib.Vector2) CollisionTup {
    var tup = CollisionTup{ .bool = false, .point = undefined, .rec_idx = undefined };
    outer: for (enemyList.items, 0..) |rec, i| {
        var x: f32 = rec.x;
        while (x <= rec.x + rec.width) : (x += 1.0) {
            var y: f32 = rec.y;
            while (y <= rec.y + rec.height) : (y += 1.0) {
                const collision_point = raylib.Vector2.init(x, y);
                if (raylib.checkCollisionPointLine(collision_point, line_start, line_end, 1)) {
                    tup = CollisionTup{ .bool = true, .point = collision_point, .rec_idx = i };
                    break :outer;
                }
            }
        }
    }

    return tup;
}

pub fn main() anyerror!void {
    raylib.initWindow(screenWidth, screenHeight, "Death is a Blessing concept test");
    defer raylib.closeWindow();

    var numCollisions: usize = 0;

    var ballPos = raylib.Vector2.init(screenWidth / 2, screenHeight / 2);
    var mousePos = raylib.Vector2.init(0, 0);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const test_alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    var enemyList: std.ArrayList(raylib.Rectangle) = std.ArrayList(raylib.Rectangle).init(gpa.allocator());
    defer enemyList.deinit();

    raylib.setTargetFPS(60);

    const rec = raylib.Rectangle.init(900, 600, 30, 30);
    try enemyList.append(rec);

    while (!raylib.windowShouldClose()) {
        // Get input and update
        if (ballPos.x >= screenWidth - radius_int) ballPos.x = screenWidth - radius_int;
        if (ballPos.x <= 0 + radius_int) ballPos.x = 0 + radius_int;
        if (ballPos.y >= screenHeight - radius_int) ballPos.y = screenHeight - radius_int;
        if (ballPos.y <= 0 + radius_int) ballPos.y = 0 + radius_int;
        if (raylib.isKeyDown(raylib.KeyboardKey.key_w)) ballPos.y -= 2.0;
        if (raylib.isKeyDown(raylib.KeyboardKey.key_a)) ballPos.x -= 2.0;
        if (raylib.isKeyDown(raylib.KeyboardKey.key_s)) ballPos.y += 2.0;
        if (raylib.isKeyDown(raylib.KeyboardKey.key_d)) ballPos.x += 2.0;

        mousePos = raylib.getMousePosition();
        mousePos.x = @as(f32, @floatFromInt(raylib.getMouseX()));
        mousePos.y = @as(f32, @floatFromInt(raylib.getMouseY()));

        const mouse_line_end = calulateLineToEdgeV(ballPos, mousePos);
        // const mouse_line_aim = calculateAimLine(ballPos, mousePos);

        // draw
        raylib.beginDrawing();
        defer raylib.endDrawing();

        // raylib.hideCursor();

        const string = try std.fmt.allocPrintZ(test_alloc, "move da ball, x: {d}, y: {d}, #. enemies: {d}, hits: {d}", .{ ballPos.x, ballPos.y, enemyList.items.len, numCollisions });
        defer test_alloc.free(string);

        raylib.clearBackground(raylib.Color.white);
        raylib.drawText(string, 10, 10, 20, raylib.Color.black);
        raylib.drawCircleV(ballPos, radius, raylib.Color.green);
        // raylib.drawLineV(ballPos, mouse_line_aim, raylib.Color.gray);

        drawEnemies(&enemyList);
        updateEnemyPos(ballPos, &enemyList);

        // check for collision between shot path and target
        if (raylib.isMouseButtonReleased(raylib.MouseButton.mouse_button_left)) {
            const collision = checkCollisionLineRec(&enemyList, ballPos, mouse_line_end);
            if (collision.bool == true) {
                numCollisions += 1;
                raylib.drawText("COLLISION!", 900, 10, 20, raylib.Color.green);
                raylib.drawLineV(ballPos, collision.point, raylib.Color.dark_green);
                _ = enemyList.orderedRemove(collision.rec_idx);
                // continue;
            } else {
                raylib.drawLineV(ballPos, mouse_line_end, raylib.Color.gray);
                try spawnEnemy(mouse_line_end, &enemyList);
            }
        }
    }
}
