const std = @import("std");
const raylib = @import("raylib");
const rlib_math = @import("raylib-math");
// const rlgl = @import("rlgl");

pub fn main() anyerror!void {
    const screenWidth = 1080;
    const screenHeight = 720;

    raylib.initWindow(screenWidth, screenHeight, "raylib [core] example - basic window w/ kb input");
    defer raylib.closeWindow();

    var ballPos = raylib.Vector2.init(screenWidth / 2, screenHeight / 2);

    raylib.setTargetFPS(60);

    while (!raylib.windowShouldClose()) {
        // Get input and update
        if (raylib.isKeyDown(raylib.KeyboardKey.key_right)) {
            ballPos.x += 2.0;
        }
        if (raylib.isKeyDown(raylib.KeyboardKey.key_left)) {
            ballPos.x -= 2.0;
        }
        if (raylib.isKeyDown(raylib.KeyboardKey.key_up)) {
            ballPos.y -= 2.0;
        }
        if (raylib.isKeyDown(raylib.KeyboardKey.key_down)) {
            ballPos.y += 2.0;
        }

        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.clearBackground(raylib.Color.white);
        raylib.drawText("Move da ball", 10, 10, 20, raylib.Color.black);
        raylib.drawCircleV(ballPos, 50.0, raylib.Color.maroon);
    }
}
