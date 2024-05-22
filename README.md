# Conceptual tester for DiaB
Now that this is public I guess it needs an actual readme! This is just a repo to test out game engine stuff for a game idea I've had for years, that I've titled Death is a Blessing.

I'd also like to get advice from people about how to proceed with certain issues.

### Tech Stack
I'm using:

  - Zig (v0.12.0)
  - [Raylib](https://github.com/raysan5/raylib) [bindings for zig](https://github.com/Not-Nik/raylib-zig)
    - Specifically raylib v5.1-dev

### Running the game
  1. Install zig
    - `brew install zig` usually works
  2. Fetch zig-raylib (from within the repo)
    - `zig fetch --save https://github.com/Not-Nik/raylib-zig/archive/devel.tar.gz`
  3. `zig build run`

I try to leave the main branch in a state where it'll always compile and run, but that's not guaranteed tbqh.
    
