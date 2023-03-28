const std = @import("std");
const zm = @import("zmath");
const zglfw = @import("zglfw");
const math = @import("../math/math.zig");
const pixi = @import("root");

pub const callbacks = @import("callbacks.zig");

pub const Keys = enum(usize) {
    primary_modifier,
    secondary_modifier,
    alternate,
};

pub const Controls = struct {
    mouse: Mouse = .{},

    /// Holds all rebindable keys.
    keys: [3]Key = [_]Key{ .{
        .name = "Primary Modifier",
        .primary = zglfw.Key.left_control,
        .secondary = zglfw.Key.left_super,
        .default_primary = zglfw.Key.left_control,
        .default_secondary = zglfw.Key.left_super,
    }, .{
        .name = "Secondary Modifier",
        .primary = zglfw.Key.left_shift,
        .secondary = zglfw.Key.right_shift,
        .default_primary = zglfw.Key.left_shift,
        .default_secondary = zglfw.Key.right_shift,
    }, .{
        .name = "Alternate",
        .primary = zglfw.Key.left_alt,
        .secondary = zglfw.Key.right_alt,
        .default_primary = zglfw.Key.left_alt,
        .default_secondary = zglfw.Key.right_alt,
    } },

    pub fn key(self: Controls, k: Keys) Key {
        return self.keys[@enumToInt(k)];
    }

    pub fn zoom(self: Controls) bool {
        return if (pixi.state.settings.input_scheme == .trackpad) self.key(Keys.primary_modifier).state else !self.key(Keys.primary_modifier).state;
    }

    pub fn sample(self: Controls) bool {
        return self.key(Keys.alternate).state;
    }
};

pub const Key = struct {
    name: [:0]const u8,
    primary: zglfw.Key = zglfw.Key.unknown,
    secondary: zglfw.Key = zglfw.Key.unknown,
    default_primary: zglfw.Key = zglfw.Key.unknown,
    default_secondary: zglfw.Key = zglfw.Key.unknown,
    state: bool = false,
    previous_state: bool = false,

    /// Returns true the frame the key was pressed.
    pub fn pressed(self: Key) bool {
        return (self.state == true and self.state != self.previous_state);
    }

    /// Returns true while the key is pressed down.
    pub fn down(self: Key) bool {
        return self.state == true;
    }

    /// Returns true the frame the key was released.
    pub fn released(self: Key) bool {
        return (self.state == false and self.state != self.previous_state);
    }

    /// Returns true while the key is released.
    pub fn up(self: Key) bool {
        return self.state == false;
    }
};

pub const MouseButton = struct {
    name: [:0]const u8,
    button: zglfw.MouseButton,
    state: bool = false,
    previous_state: bool = false,

    /// Returns true the frame the mouse button was pressed.
    pub fn pressed(self: MouseButton) bool {
        return self.state == true and self.state != self.previous_state;
    }

    /// Returns true while the mouse button is pressed down.
    pub fn down(self: MouseButton) bool {
        return self.state == true;
    }

    /// Returns true the frame the mouse button was released.
    pub fn released(self: MouseButton) bool {
        return self.state == false and self.state != self.previous_state;
    }

    /// Returns true while the mouse button is released.
    pub fn up(self: MouseButton) bool {
        return self.state == false;
    }
};

pub const MousePosition = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,

    /// Returns the screen position.
    pub fn screen(self: MousePosition) zm.F32x4 {
        return zm.f32x4(self.x, self.y, 0, 0);
    }

    /// Returns the world position.
    pub fn world(self: MousePosition) zm.F32x4 {
        const fb = pixi.state.camera.frameBufferMatrix();
        const position = self.screen();
        return pixi.state.camera.screenToWorld(position, fb);
    }

    pub fn toSlice(self: MousePosition) [2]f32 {
        return .{ self.x, self.y };
    }
};

pub const MouseCursor = enum {
    standard,
    drag,
};

pub const Mouse = struct {
    primary: MouseButton = .{ .name = "Primary", .button = zglfw.MouseButton.left },
    secondary: MouseButton = .{ .name = "Secondary", .button = zglfw.MouseButton.right },
    position: MousePosition = .{},
    scroll_x: ?f32 = null,
    scroll_y: ?f32 = null,
    cursor: MouseCursor = .standard,
};
