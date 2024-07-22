const std = @import("std");
const pixi = @import("../../../pixi.zig");
const mach = @import("mach");
const core = mach.core;
const imgui = @import("zig-imgui");
const zmath = @import("zmath");

pub fn draw(file: *pixi.storage.Internal.Pixi) void {
    const window_height = imgui.getWindowHeight();
    const window_width = imgui.getWindowWidth();
    const tile_width = @as(f32, @floatFromInt(file.tile_width));
    const tile_height = @as(f32, @floatFromInt(file.tile_height));
    const canvas_center_offset: [2]f32 = file.canvasCenterOffset(.flipbook);
    const window_position = imgui.getWindowPos();

    const grip_size: f32 = 10.0;
    const half_grip_size = grip_size / 2.0;
    const scaled_grip_size = grip_size / file.flipbook_camera.zoom;

    const frame_circle_radius: f32 = 5.0;

    imgui.pushStyleColorImVec4(imgui.Col_ChildBg, pixi.state.theme.foreground.toImguiVec4());

    const animation_opt: ?*pixi.storage.Internal.KeyframeAnimation = if (file.keyframe_animations.items.len > 0) &file.keyframe_animations.items[file.selected_keyframe_animation_index] else null;

    const timeline_height = imgui.getWindowHeight() * 0.33;

    const test_animation_length: f32 = 1.37;

    const length: f32 = test_animation_length;
    const animation_ms: usize = @intFromFloat(length * 1000.0);
    const zoom: f32 = 1.0;

    var timeline_hovered: bool = false;

    if (timeline_height > 50.0) {
        if (imgui.beginChild("FlipbookTimeline", .{ .x = -1.0, .y = timeline_height }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow | imgui.WindowFlags_HorizontalScrollbar)) {
            defer imgui.endChild();

            if (imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows))
                timeline_hovered = true;

            const scroll_x = imgui.getScrollX();
            const scroll_y = imgui.getScrollY();

            var rows: f32 = 0;

            if (animation_opt) |animation| {
                for (animation.keyframes.items) |keyframe| {
                    const new_rows: f32 = @floatFromInt(keyframe.frames.items.len);
                    if (new_rows > rows)
                        rows = new_rows;
                }
            }

            const timeline_scroll_height: f32 = @max(timeline_height - imgui.getTextLineHeight(), rows * (frame_circle_radius * 2.0 + 4.0)) + 12.0;

            if (imgui.beginChild("FlipbookTimelineScroll", .{ .x = animation_ms * zoom, .y = timeline_scroll_height }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
                defer imgui.endChild();

                if (imgui.getWindowDrawList()) |draw_list| {
                    var rel_mouse_x: ?f32 = null;
                    var rel_mouse_y: ?f32 = null;
                    var window_hovered: bool = false;
                    if (imgui.isWindowHovered(imgui.HoveredFlags_ChildWindows)) {
                        const mouse_position = pixi.state.mouse.position;
                        rel_mouse_x = mouse_position[0] - window_position.x + scroll_x;
                        rel_mouse_y = mouse_position[1] - window_position.y + scroll_y;
                        window_hovered = true;
                    }

                    blk: {
                        for (0..animation_ms) |index_ms| {
                            var width: f32 = @floatFromInt(index_ms);
                            const line_hovered: bool = if (rel_mouse_x) |mouse_x| @abs(width - (mouse_x / zoom)) < 5.0 else false;

                            var thickness: f32 = 1.0;
                            var line_color = if (line_hovered) pixi.state.theme.highlight_primary.toU32() else pixi.state.theme.background.toU32();
                            width *= zoom;

                            if (@mod(index_ms, 100) == 0) thickness = 2.0;
                            if (@mod(index_ms, 1000) == 0) thickness = 4.0;

                            if (@mod(index_ms, 10) == 0) {
                                if (line_hovered and window_hovered) {
                                    if (animation_opt) |animation| {
                                        for (animation.keyframes.items) |*keyframe| {
                                            const x = imgui.getWindowPos().x + (keyframe.time * 1000.0);

                                            var y: f32 = window_position.y + imgui.getTextLineHeightWithSpacing();

                                            const step: f32 = (frame_circle_radius * 2.0) + 4.0;

                                            for (keyframe.frames.items, 0..) |frame, i| {
                                                y = (imgui.getWindowPos().y + 12.0) + step * @as(f32, @floatFromInt(i));

                                                if (rel_mouse_x) |mouse_x| {
                                                    if (@abs((x - window_position.x - scroll_x) - mouse_x) <= frame_circle_radius) {
                                                        if (rel_mouse_y) |mouse_y| {
                                                            if (@abs((y - window_position.y + scroll_y) - mouse_y) <= frame_circle_radius) {
                                                                if (pixi.state.mouse.button(.primary)) |bt| {
                                                                    if (bt.pressed()) {
                                                                        file.selected_sprites.clearAndFree();
                                                                        file.selected_sprites.append(frame.sprite_index) catch unreachable;

                                                                        animation.active_keyframe_id = keyframe.id;
                                                                        keyframe.active_frame_id = frame.id;

                                                                        break :blk;
                                                                    }
                                                                }

                                                                line_color = pixi.state.theme.background.toU32();
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    if (pixi.state.mouse.button(.primary)) |bt| {
                                        if (bt.pressed()) {
                                            var keyframe_opt: ?*pixi.storage.Internal.Keyframe = null;

                                            const current_time = @as(f32, @floatFromInt(index_ms)) / 1000.0;

                                            if (animation_opt) |animation| {
                                                for (animation.keyframes.items) |*kf| {
                                                    if (current_time == kf.time)
                                                        keyframe_opt = kf;
                                                }
                                            }

                                            if (keyframe_opt) |keyframe| {
                                                for (file.selected_sprites.items) |selected_sprite| {
                                                    const origin = zmath.loadArr2(.{ file.sprites.items[selected_sprite].origin_x, file.sprites.items[selected_sprite].origin_y });

                                                    const new_frame: pixi.storage.Internal.Frame = .{
                                                        .id = file.newId(),
                                                        .sprite_index = selected_sprite,
                                                        .layer_id = file.layers.items[file.selected_layer_index].id,
                                                        .pivot = .{ .position = zmath.f32x4s(0.0) },
                                                        .vertices = .{
                                                            .{ .position = -origin }, // TL
                                                            .{ .position = zmath.loadArr2(.{ tile_width, 0.0 }) - origin }, // TR
                                                            .{ .position = zmath.loadArr2(.{ tile_width, tile_height }) - origin }, //BR
                                                            .{ .position = zmath.loadArr2(.{ 0.0, tile_height }) - origin }, // BL
                                                        },
                                                    };

                                                    keyframe.frames.append(new_frame) catch unreachable;
                                                    keyframe.active_frame_id = new_frame.id;
                                                }
                                            } else {
                                                var new_keyframe: pixi.storage.Internal.Keyframe = .{
                                                    .frames = std.ArrayList(pixi.storage.Internal.Frame).init(pixi.state.allocator),
                                                    .id = file.newId(),
                                                    .active_frame_id = 0,
                                                    .time = current_time,
                                                };

                                                for (file.selected_sprites.items) |selected_sprite| {
                                                    const origin = zmath.loadArr2(.{ file.sprites.items[selected_sprite].origin_x, file.sprites.items[selected_sprite].origin_y });

                                                    const new_frame: pixi.storage.Internal.Frame = .{
                                                        .id = file.newId(),
                                                        .sprite_index = selected_sprite,
                                                        .layer_id = file.layers.items[file.selected_layer_index].id,
                                                        .pivot = .{ .position = zmath.f32x4s(0.0) },
                                                        .vertices = .{
                                                            .{ .position = -origin }, // TL
                                                            .{ .position = zmath.loadArr2(.{ tile_width, 0.0 }) - origin }, // TR
                                                            .{ .position = zmath.loadArr2(.{ tile_width, tile_height }) - origin }, //BR
                                                            .{ .position = zmath.loadArr2(.{ 0.0, tile_height }) - origin }, // BL
                                                        },
                                                    };

                                                    new_keyframe.frames.append(new_frame) catch unreachable;
                                                }

                                                new_keyframe.active_frame_id = new_keyframe.frames.items[new_keyframe.frames.items.len - 1].id;

                                                if (animation_opt) |animation| {
                                                    animation.keyframes.append(new_keyframe) catch unreachable;
                                                    animation.active_keyframe_id = new_keyframe.id;
                                                } else {
                                                    var new_animation: pixi.storage.Internal.KeyframeAnimation = .{
                                                        .keyframes = std.ArrayList(pixi.storage.Internal.Keyframe).init(pixi.state.allocator),
                                                        .name = "New Transform Animation",
                                                        .id = file.newId(),
                                                        .active_keyframe_id = new_keyframe.id,
                                                    };

                                                    new_animation.keyframes.append(new_keyframe) catch unreachable;
                                                    new_animation.active_keyframe_id = new_keyframe.id;
                                                    file.keyframe_animations.append(new_animation) catch unreachable;
                                                }
                                            }
                                        }
                                    }
                                }

                                draw_list.addLineEx(
                                    .{ .x = window_position.x + width - scroll_x, .y = window_position.y },
                                    .{ .x = window_position.x + width - scroll_x, .y = window_position.y + timeline_height - imgui.getTextLineHeight() },
                                    line_color,
                                    thickness,
                                );
                            }

                            if (@mod(index_ms, 1000) == 0) {
                                const fmt = std.fmt.allocPrintZ(pixi.state.allocator, "{d} s", .{@divTrunc(index_ms, 1000)}) catch unreachable;
                                defer pixi.state.allocator.free(fmt);

                                draw_list.addText(
                                    .{ .x = window_position.x + width - scroll_x, .y = window_position.y + timeline_height - imgui.getTextLineHeight() },
                                    pixi.state.theme.text.toU32(),
                                    fmt.ptr,
                                );
                            } else if (@mod(index_ms, 100) == 0) {
                                const fmt = std.fmt.allocPrintZ(pixi.state.allocator, "{d} ms", .{index_ms}) catch unreachable;
                                defer pixi.state.allocator.free(fmt);

                                draw_list.addText(
                                    .{ .x = window_position.x + width - scroll_x, .y = window_position.y + timeline_height - imgui.getTextLineHeight() },
                                    pixi.state.theme.text.toU32(),
                                    fmt.ptr,
                                );
                            }
                        }
                    }

                    if (animation_opt) |animation| {
                        for (animation.keyframes.items) |keyframe| {
                            const x = imgui.getWindowPos().x + (keyframe.time * 1000.0);

                            var y: f32 = window_position.y + imgui.getTextLineHeightWithSpacing();
                            const step: f32 = (frame_circle_radius * 2.0) + 4.0;

                            for (keyframe.frames.items, 0..) |frame, i| {
                                const color_index: usize = @mod(frame.id * 2, 35);

                                y = (imgui.getWindowPos().y + 12.0) + step * @as(f32, @floatFromInt(i));

                                const color = if (pixi.state.colors.keyframe_palette) |palette| pixi.math.Color.initBytes(
                                    palette.colors[color_index][0],
                                    palette.colors[color_index][1],
                                    palette.colors[color_index][2],
                                    palette.colors[color_index][3],
                                ).toU32() else pixi.state.theme.text.toU32();

                                var scale_mult: f32 = 1.0;

                                if (rel_mouse_x) |mouse_x| {
                                    if (@abs((x - window_position.x - scroll_x) - mouse_x) <= frame_circle_radius) {
                                        if (rel_mouse_y) |mouse_y| {
                                            if (@abs((y - window_position.y + scroll_y) - mouse_y) <= frame_circle_radius) {
                                                scale_mult = 2.0;
                                            }
                                        }
                                    }
                                }

                                draw_list.addCircleFilled(.{ .x = x, .y = y }, frame_circle_radius * scale_mult, color, 10 * @as(c_int, @intFromFloat(scale_mult)));
                            }
                        }
                    }
                }
            }
        }
    }

    imgui.popStyleColor();

    if (imgui.beginChild("FlipbookCanvas", .{ .x = window_width, .y = 0.0 }, imgui.ChildFlags_None, imgui.WindowFlags_ChildWindow)) {
        defer imgui.endChild();

        // // Progress flipbook scroll request
        // if (file.flipbook_scroll_request) |*request| {
        //     if (request.elapsed < 0.5) {
        //         file.selected_animation_state = .pause;
        //         request.elapsed += pixi.state.delta_time;
        //         file.flipbook_scroll = pixi.math.ease(request.from, request.to, request.elapsed / 0.5, .ease_in_out);
        //     } else {
        //         file.flipbook_scroll = request.to;
        //         file.selected_animation_state = request.state;
        //         file.flipbook_scroll_request = null;
        //     }
        // }

        // for (file.sprites.items, 0..) |_, i| {
        //     const sprite_scale = std.math.clamp(0.4 / @abs(@as(f32, @floatFromInt(i)) / 1.2 + (file.flipbook_scroll / tile_width / 1.2)), 0.4, 1.0);

        //     if (sprite_scale >= 1.0) {
        //         file.selected_sprite_index = i;
        //         if (!file.setAnimationFromSpriteIndex()) {
        //             file.selected_animation_state = .pause;
        //         }
        //     }
        // }

        // Handle zooming, panning and extents
        {
            var sprite_camera: pixi.gfx.Camera = .{
                .zoom = window_height / tile_height,
            };
            const zoom_index = sprite_camera.nearestZoomIndex();
            const max_zoom_index = if (zoom_index < pixi.state.settings.zoom_steps.len - 2) zoom_index + 2 else zoom_index;
            const max_zoom = pixi.state.settings.zoom_steps[max_zoom_index];
            sprite_camera.setNearZoomFloor();
            const min_zoom = 1.0;

            file.flipbook_camera.processPanZoom();

            // Lock camera from zooming in or out too far for the flipbook
            file.flipbook_camera.zoom = std.math.clamp(file.flipbook_camera.zoom, min_zoom, max_zoom);

            const view_width: f32 = tile_width * 4.0;
            const view_height: f32 = tile_height * 4.0;

            // Lock camera from moving too far away from canvas
            const min_position: [2]f32 = .{ canvas_center_offset[0] - view_width / 2.0, canvas_center_offset[1] - view_height / 2.0 };
            const max_position: [2]f32 = .{ canvas_center_offset[0] + view_width, canvas_center_offset[1] + view_height };

            file.flipbook_camera.position[0] = std.math.clamp(file.flipbook_camera.position[0], min_position[0], max_position[0]);
            file.flipbook_camera.position[1] = std.math.clamp(file.flipbook_camera.position[1], min_position[1], max_position[1]);
        }

        const grid_columns: f32 = 20;
        const grid_rows: f32 = 20;
        const grid_width: f32 = tile_width * grid_columns;
        const grid_height: f32 = tile_height * grid_rows;

        file.flipbook_camera.drawGrid(.{ -grid_width / 2.0, -grid_height / 2.0 }, grid_width, grid_height, @intFromFloat(grid_columns), @intFromFloat(grid_rows), pixi.state.theme.text_background.toU32(), true);
        file.flipbook_camera.drawCircleFilled(.{ 0.0, 0.0 }, half_grip_size, pixi.state.theme.text_background.toU32());

        const l: f32 = 2000;
        file.flipbook_camera.drawLine(.{ 0.0, l / 2.0 }, .{ 0.0, -l / 2.0 }, 0x5500FF00, 1.0);
        file.flipbook_camera.drawLine(.{ -l / 2.0, 0.0 }, .{ l / 2.0, 0.0 }, 0x550000FF, 1.0);

        file.flipbook_camera.drawTexture(
            file.keyframe_animation_texture.view_handle,
            file.keyframe_animation_texture.image.width,
            file.keyframe_animation_texture.image.height,
            file.canvasCenterOffset(.primary),
            0xFFFFFFFF,
        );

        if (file.keyframe_animations.items.len > 0) {
            const selected_animation = &file.keyframe_animations.items[file.selected_keyframe_animation_index];

            var active_keyframe_index: usize = 0;
            for (selected_animation.keyframes.items, 0..) |keyframe, i| {
                if (keyframe.id == selected_animation.active_keyframe_id)
                    active_keyframe_index = i;
            }

            var selected_keyframe: *pixi.storage.Internal.Keyframe = &selected_animation.keyframes.items[active_keyframe_index];

            // Draw transform texture on gpu to temporary texture

            const width: f32 = @floatFromInt(file.width);
            const height: f32 = @floatFromInt(file.height);

            const uniforms = pixi.gfx.UniformBufferObject{ .mvp = zmath.transpose(
                zmath.orthographicLh(width, height, -100, 100),
            ) };

            for (selected_keyframe.frames.items) |*frame| {
                const color_index: usize = @mod(frame.id * 2, 35);

                const color = if (pixi.state.colors.keyframe_palette) |palette| pixi.math.Color.initBytes(
                    palette.colors[color_index][0],
                    palette.colors[color_index][1],
                    palette.colors[color_index][2],
                    palette.colors[color_index][3],
                ).toU32() else pixi.state.theme.text.toU32();

                if (file.layer(frame.layer_id)) |layer| {
                    if (layer.transform_bindgroup) |transform_bindgroup| {
                        pixi.state.batcher.begin(.{
                            .pipeline_handle = pixi.state.pipeline_default,
                            .bind_group_handle = transform_bindgroup,
                            .output_texture = &file.keyframe_animation_texture,
                            .clear_color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 },
                        }) catch unreachable;

                        if (file.flipbook_camera.isHovered(.{
                            frame.pivot.position[0] - scaled_grip_size / 2.0,
                            frame.pivot.position[1] - scaled_grip_size / 2.0,
                            scaled_grip_size,
                            scaled_grip_size,
                        })) {
                            if (pixi.state.mouse.button(.primary)) |bt| {
                                if (bt.pressed()) {
                                    var change: bool = true;

                                    if (pixi.state.hotkeys.hotkey(.{ .proc = .secondary })) |hk| {
                                        if (hk.down()) {
                                            frame.parent_id = null;
                                            change = false;
                                        }
                                    }

                                    if (frame.id != selected_keyframe.active_frame_id) {
                                        if (pixi.state.hotkeys.hotkey(.{ .proc = .primary })) |hk| {
                                            if (hk.down()) {
                                                if (selected_keyframe.frame(selected_keyframe.active_frame_id)) |active_frame| {
                                                    active_frame.parent_id = frame.id;
                                                }

                                                change = false;
                                            }
                                        }
                                        if (change) {
                                            selected_keyframe.active_frame_id = frame.id;

                                            // if (selected_keyframe.frame(selected_keyframe.active_frame_id)) |active_frame| {
                                            //     file.flipbook_scroll_request = .{
                                            //         .from = file.flipbook_scroll,
                                            //         .to = file.flipbookScrollFromSpriteIndex(active_frame.sprite_index),
                                            //         .state = file.selected_animation_state,
                                            //     };
                                            // }
                                        }
                                    }
                                }
                            }
                            file.flipbook_camera.drawCircleFilled(
                                .{ frame.pivot.position[0], frame.pivot.position[1] },
                                half_grip_size * 2.0,
                                color,
                            );
                        } else {
                            file.flipbook_camera.drawCircleFilled(
                                .{ frame.pivot.position[0], frame.pivot.position[1] },
                                half_grip_size,
                                color,
                            );
                        }

                        const tiles_wide = @divExact(file.width, file.tile_width);

                        const src_col = @mod(@as(u32, @intCast(frame.sprite_index)), tiles_wide);
                        const src_row = @divTrunc(@as(u32, @intCast(frame.sprite_index)), tiles_wide);

                        const src_x = src_col * file.tile_width;
                        const src_y = src_row * file.tile_height;

                        const sprite: pixi.gfx.Sprite = .{
                            .name = "",
                            .origin = .{ 0, 0 },
                            .source = .{
                                src_x,
                                src_y,
                                file.tile_width,
                                file.tile_height,
                            },
                        };

                        var rotation = -frame.rotation;

                        if (frame.parent_id) |parent_id| {
                            for (selected_keyframe.frames.items) |parent_frame| {
                                if (parent_frame.id == parent_id) {
                                    const diff = parent_frame.pivot.position - frame.pivot.position;

                                    const angle = std.math.atan2(diff[1], diff[0]);

                                    rotation -= std.math.radiansToDegrees(angle) - 90.0;

                                    file.flipbook_camera.drawLine(
                                        .{ frame.pivot.position[0], frame.pivot.position[1] },
                                        .{ parent_frame.pivot.position[0], parent_frame.pivot.position[1] },
                                        color,
                                        1.0,
                                    );
                                }
                            }
                        }

                        pixi.state.batcher.transformSprite(
                            &layer.texture,
                            sprite,
                            frame.vertices,
                            .{ 0.0, 0.0 },
                            .{ frame.pivot.position[0], -frame.pivot.position[1] },
                            .{
                                .rotation = rotation,
                            },
                        ) catch unreachable;

                        pixi.state.batcher.end(uniforms, pixi.state.uniform_buffer_default) catch unreachable;
                    }

                    if (selected_keyframe.active_frame_id == frame.id) {
                        // Write from the frame to the transform texture
                        @memcpy(&file.keyframe_transform_texture.vertices, &frame.vertices);
                        file.keyframe_transform_texture.pivot = frame.pivot;
                        file.keyframe_transform_texture.rotation = frame.rotation;

                        // Write parent id
                        if (frame.parent_id) |parent_id| {
                            file.keyframe_transform_texture.keyframe_parent_id = parent_id;
                        }

                        // Process transform texture controls
                        file.processTransformTextureControls(&file.keyframe_transform_texture, .{
                            .canvas = .flipbook,
                            .allow_pivot_move = false,
                            .allow_vert_move = false,
                            .color = color,
                        });

                        // Clear the parent
                        file.keyframe_transform_texture.keyframe_parent_id = null;

                        // Write back to the frame
                        @memcpy(&frame.vertices, &file.keyframe_transform_texture.vertices);
                        frame.pivot = file.keyframe_transform_texture.pivot.?;
                        frame.rotation = file.keyframe_transform_texture.rotation;
                    }

                    // We are using a load on the gpu texture, so we need to clear this texture on the gpu after we are done
                    @memset(file.keyframe_animation_texture.image.data, 0.0);
                    file.keyframe_animation_texture.update(core.device);
                }
            }
        }
    }
}
