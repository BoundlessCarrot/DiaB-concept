/// This file contains the game logic for the game. It is responsible for updating the game state
/// The game state is managed by the main loop in the main.zig file
const std = @import("std");
const raylib = @import("raylib");

const vec2f = raylib.Vector2;
const ZERO_VECTOR = vec2f.init(0, 0);
const mouseAngle = normalMouseAngle;
const clamp = std.math.clamp;

const settings = @import("settings.zig");
const screenWidth = settings.screenWidth;
const screenHeight = settings.screenHeight;
const radius = settings.radius;
const radius_int = settings.radius_int;

var dprng = std.rand.DefaultPrng.init(0);
const rand = dprng.random();

/// Type to hold collision information between a shot and an enemy
const CollisionTup = struct {
    /// Whether the shot collided with an enemy
    bool: bool,
    /// The point of collision
    point: vec2f,
    /// The index of the rectangle in the enemy list that was hit
    rec_idx: usize,
};

/// Clear the enemy list
pub fn clearEnemyList(enemyList: *std.ArrayList(raylib.Rectangle)) !void {
    enemyList.resize(0) catch @panic("Failed to clear enemy list");
}

/// Angle from the player to the mouse - straight through
fn normalMouseAngle(center: vec2f, mouse: vec2f) f32 {
    return std.math.atan2(mouse.y - center.y, mouse.x - center.x);
}

/// Angle from the player to the mouse - mirrored
fn mirroredMouseAngle(center: vec2f, mouse: vec2f) f32 {
    return std.math.atan2(center.y - mouse.y, center.x - mouse.x);
}

/// Calculate the path for the player to shoot at, to the edge of the screen
pub fn calculateAimPathV(player: vec2f, mouse: vec2f) vec2f {
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

/// Calculate the aiming line for the player, to 3x the radius of the player
pub fn calculateAimLineV(player: vec2f, mouse: vec2f) vec2f {
    const angle = mouseAngle(player, mouse);
    const line_length = radius * 3; // Adjust this value to change the line length

    const end_x = player.x + line_length * std.math.cos(angle);
    const end_y = player.y + line_length * std.math.sin(angle);

    return vec2f.init(end_x, end_y);
}

/// Add an enemy to the enemy list
pub fn spawnEnemy(missedShotCoords: vec2f, enemyList: *std.ArrayList(raylib.Rectangle)) !void {
    for (0..rand.intRangeAtMost(usize, 1, 5)) |_| {
        const offset = vec2f.init(rand.float(f32) * 10, rand.float(f32) * 10);
        const rec = raylib.Rectangle.init(missedShotCoords.x + offset.x, missedShotCoords.y + offset.y, 10, 10);
        try enemyList.append(rec);
    }
}

/// Draw the enemies to the screen
pub fn drawEnemies(enemyList: *std.ArrayList(raylib.Rectangle)) void {
    for (enemyList.items) |enemy| {
        raylib.drawRectangleRec(enemy, raylib.Color.red);
    }
}

/// Update the position of the enemies on the screen
pub fn updateEnemyPos(player: vec2f, enemyList: *std.ArrayList(raylib.Rectangle)) void {
    for (0..enemyList.items.len) |i| {
        const rec = enemyList.items[i];
        const originToPlayer = subtractVectors(player, ZERO_VECTOR);
        const originToEnemy = subtractVectors(vec2f.init(rec.x, rec.y), ZERO_VECTOR);
        const enemyToPlayer = subtractVectors(originToPlayer, originToEnemy);
        const normalized = normalizeVector(enemyToPlayer);
        enemyList.items[i] = raylib.Rectangle.init(rec.x + (normalized.x * 2), rec.y + (normalized.y * 2), rec.width, rec.height);
    }
}

/// HELPER FUNCTION: Subtract two vectors
fn subtractVectors(a: vec2f, b: vec2f) vec2f {
    return vec2f.init(a.x - b.x, a.y - b.y);
}

/// HELPER FUNCTION: Normalize a vector
fn normalizeVector(v: vec2f) vec2f {
    const len = std.math.sqrt(v.x * v.x + v.y * v.y);
    return vec2f.init(v.x / len, v.y / len);
}

/// Check if a shot has collided with an enemy
pub fn checkCollisionLineRec(enemyList: *std.ArrayList(raylib.Rectangle), line_start: vec2f, line_end: vec2f) CollisionTup {
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

/// Check if an enemy has collided with the player
pub fn checkCollisionEnemyPlayer(enemyList: *std.ArrayList(raylib.Rectangle), player: vec2f) bool {
    for (enemyList.items) |rec| {
        if (raylib.checkCollisionCircleRec(player, radius, rec)) {
            // raylib.drawText("DEATH!", 900, 10, 20, raylib.Color.red);
            return true;
        }
    }
    return false;
}

/// Spawn starting enemies, with randomized positions
pub fn spawnInitialEnemies(enemyList: *std.ArrayList(raylib.Rectangle)) !void {
    for (0..8) |_| {
        const coords = vec2f.init(rand.float(f32) * 1080, rand.float(f32) * 720);
        const rec = raylib.Rectangle.init(coords.x, coords.y, 10, 10);
        try enemyList.append(rec);
    }
}

/// Update the player's position based on input
pub fn updatePlayerPos(player: *vec2f) void {
    if (player.x >= screenWidth - radius_int) player.x = screenWidth - radius_int;
    if (player.x <= 0 + radius_int) player.x = 0 + radius_int;
    if (player.y >= screenHeight - radius_int) player.y = screenHeight - radius_int;
    if (player.y <= 0 + radius_int) player.y = 0 + radius_int;
    if (raylib.isKeyDown(raylib.KeyboardKey.key_w)) player.y -= 2.5;
    if (raylib.isKeyDown(raylib.KeyboardKey.key_a)) player.x -= 2.5;
    if (raylib.isKeyDown(raylib.KeyboardKey.key_s)) player.y += 2.5;
    if (raylib.isKeyDown(raylib.KeyboardKey.key_d)) player.x += 2.5;
}

/// Update the mouse position
pub fn updateMousePos(mousePos: *vec2f) void {
    mousePos.* = raylib.getMousePosition();
    mousePos.x = @as(f32, @floatFromInt(raylib.getMouseX()));
    mousePos.y = @as(f32, @floatFromInt(raylib.getMouseY()));
}

/// Draw the player and aiming guide to the screen
pub fn drawPlayer(player: vec2f, aimLine: vec2f) void {
    raylib.drawCircleV(player, radius, raylib.Color.green);
    raylib.drawLineV(player, aimLine, raylib.Color.gray);
}
