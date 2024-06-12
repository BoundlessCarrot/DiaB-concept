const std = @import("std");

const raylib = @import("raylib");
const vec2f = raylib.Vector2;

// const rlib_math = @import("raylib-math");
// const rlgl = @import("rlgl");

const settings = @import("settings.zig");
const screenWidth = settings.screenWidth;
const screenHeight = settings.screenHeight;
const radius = settings.radius;

const gameAPI = @import("gameAPI.zig");
const calculateAimPathV = gameAPI.calculateAimPathV;
const calculateAimLineV = gameAPI.calculateAimLineV;
// const checkCollisionLineRec = gameAPI.checkCollisionLineRec;
const checkCollisionEnemyPlayer = gameAPI.checkCollisionEnemyPlayer;
const spawnEnemy = gameAPI.spawnEnemy;
const spawnInitialEnemies = gameAPI.spawnInitialEnemies;
const clearEnemyList = gameAPI.clearEnemyList;
const clearProjectileList = gameAPI.clearProjectiles;
const updatePlayerPos = gameAPI.updatePlayerPos;
const updateMousePos = gameAPI.updateMousePos;
const drawPlayer = gameAPI.drawPlayer;
const drawEnemies = gameAPI.drawEnemies;
const updateEnemyPos = gameAPI.updateEnemyPos;
const isPlayerShooting = gameAPI.isPlayerShooting;
const doCollisionEvent = gameAPI.doCollisionEvent;
const doMissEvent = gameAPI.doMissEvent;
const checkProjectileCollision = gameAPI.checkProjectileCollision;
const addProjectile = gameAPI.addProjectile;
const drawProjectiles = gameAPI.drawProjectiles;
const updateProjectiles = gameAPI.updateProjectiles;

const CollisionEvent = gameAPI.CollisionEvent;
const Projectile = gameAPI.Projectile;

const Screen = enum {
    MainMenu,
    Game,
    EndScreen,
};

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

    var projectileList: std.ArrayList(Projectile) = std.ArrayList(Projectile).init(gpa.allocator());
    defer projectileList.deinit();

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
                    try clearProjectileList(&projectileList);
                    try spawnInitialEnemies(&enemyList);
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
                raylib.clearBackground(raylib.Color.white);

                // Get input and update
                updatePlayerPos(&ballPos);
                updateMousePos(&mousePos);

                // debug text
                const string = try std.fmt.allocPrintZ(test_alloc, "move da ball, x: {d}, y: {d}, #. enemies: {d}, hits: {d}", .{ ballPos.x, ballPos.y, enemyList.items.len, numCollisions });
                defer test_alloc.free(string);
                raylib.drawText(string, 10, 10, 20, raylib.Color.black);

                // get aim path (to end of screen) and aim line (3x radius)
                const aimPath = calculateAimPathV(ballPos, mousePos);
                const aimLine = calculateAimLineV(ballPos, mousePos);

                drawPlayer(ballPos, aimLine);
                drawEnemies(&enemyList);
                updateEnemyPos(ballPos, &enemyList);

                // draw projectiles
                drawProjectiles(&projectileList);
                updateProjectiles(&projectileList);

                const collision = checkProjectileCollision(&enemyList, &projectileList);

                // check for collision between shot path and target
                if (isPlayerShooting()) {
                    try addProjectile(&projectileList, ballPos, aimPath);
                }

                if (collision.bool == true) {
                    doCollisionEvent(&numCollisions, &enemyList, &projectileList, collision);
                } else try doMissEvent(ballPos, aimPath, &enemyList);

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
