const std = @import("std");
const raylib = @import("raylib");
const rlib_math = @import("raylib-math");
// const rlgl = @import("rlgl");

const radius: f32 = 10.0;
const radius_int: u32 = @as(u32, radius);

const screenWidth = 1080;
const screenHeight = 720;

fn calulateLineToEdgeV(center: raylib.Vector2, mouse: raylib.Vector2) raylib.Vector2 {
    // const angle = std.math.atan2(center.y - mouse.y, center.x - mouse.x); //mirrored mouse
    const angle = std.math.atan2(mouse.y - center.y, mouse.x - center.x); //normal mouse
    const max_x = center.x + (screenWidth / 2) * std.math.cos(angle);
    const max_y = center.y + (screenWidth / 2) * std.math.sin(angle);
    return raylib.Vector2.init(max_x, max_y);
}

pub fn main() anyerror!void {
    raylib.initWindow(screenWidth, screenHeight, "raylib [core] example - basic window w/ kb input, window limits, and mouse line tracking");
    defer raylib.closeWindow();

    var ballPos = raylib.Vector2.init(screenWidth / 2, screenHeight / 2);
    var mousePos = raylib.Vector2.init(0, 0);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const test_alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    raylib.setTargetFPS(60);

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

        // draw
        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.hideCursor();

        const string = try std.fmt.allocPrintZ(test_alloc, "move da ball, x: {d}, y: {d}", .{ ballPos.x, ballPos.y });
        defer test_alloc.free(string);

        raylib.clearBackground(raylib.Color.white);
        raylib.drawText(string, 10, 10, 20, raylib.Color.black);
        raylib.drawCircleV(ballPos, radius, raylib.Color.maroon);
        raylib.drawLineV(ballPos, mouse_line_end, raylib.Color.gray);
    }
}
