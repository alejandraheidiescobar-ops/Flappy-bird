<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project is a hardware implementation of a Flappy Bird-style game designed for Tiny Tapeout. It generates real-time 640x480 at 60 Hz VGA video directly from the chip using a custom timing generator module (`hvsync_generator`).

* **Game Engine and Physics:** A finite state machine (FSM) manages the game states (Start, Play, Game Over). The bird physics rely on fixed-point signed arithmetic to simulate smooth jump impulses and continuous gravity acceleration.
* **Procedural Pipe and Terrain Generation:** The gap height for upcoming pipes is randomized using a free-running register (`rng_counter`). Background clouds and ground textures feature parallax scrolling to create depth.
* **Sprite and Graphics Rendering:** Sprites (the bird and clouds) are stored as 8-bit row bitmaps in internal logic blocks. Color assignment is handled on-the-fly pixel by pixel according to spatial coordinates (`hpos` and `vpos`).
## How to test

1. **Clock Setup:** Feed a 25.175 MHz clock signal into the `clk` pin.
2. **Reset:** Apply an active-low reset pulse (`rst_n = 0`) to initialize the game state machine and registers.
3. **Controls:** Press the jump button assigned to `ui_in[0]` or `ui_in[2]` to start the game and propel the bird upward.
4. **Gameplay:** Dodge incoming pipes. If the bird hits a pipe, the ground, or the ceiling, the game transitions to `STATE_GAMEOVER`. Pressing the jump button again resets the game back to `STATE_START`.

## External hardware

* **TinyVGA PMOD:** Connected to `uo_out[7:0]` to convert digital RGB and sync signals into analog VGA.
* **VGA Display:** Standard monitor supporting 640x480 resolution at 60 Hz.
* **Push Button:** Momentary switch connected to `ui_in[0]` or `ui_in[2]` with a pull-down resistor.
