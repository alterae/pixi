const std = @import("std");
const zgui = @import("zgui");
const pixi = @import("pixi");
const editor = pixi.editor;

pub var path_hover_timer: f32 = 0.0;

pub fn draw() void {
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.window_rounding, .v = 0.0 });
    defer zgui.popStyleVar(.{ .count = 1 });
    zgui.setNextWindowPos(.{
        .x = (pixi.state.settings.sidebar_width + pixi.state.settings.explorer_width) * pixi.state.window.scale[0],
        .y = 0,
        .cond = .always,
    });
    zgui.setNextWindowSize(.{
        .w = (pixi.state.window.size[0] - pixi.state.settings.explorer_width - pixi.state.settings.sidebar_width) * pixi.state.window.scale[0],
        .h = pixi.state.window.size[1] * pixi.state.window.scale[1] + 5.0,
    });

    zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 0.0, 0.0 } });
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.tab_rounding, .v = 0.0 });
    zgui.pushStyleVar1f(.{ .idx = zgui.StyleVar.child_border_size, .v = 1.0 });
    defer zgui.popStyleVar(.{ .count = 3 });
    if (zgui.begin("Art", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .menu_bar = true,
        },
    })) {
        editor.menu.draw();

        zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.item_spacing, .v = .{ 0.0, 0.0 } });
        defer zgui.popStyleVar(.{ .count = 1 });
        if (zgui.beginChild("Artboard", .{
            .w = 0.0,
            .h = pixi.state.window.size[1] / 1.5 * pixi.state.window.scale[1],
            .border = false,
            .flags = .{},
        })) {
            if (pixi.state.open_files.items.len > 0) {
                if (zgui.beginTabBar("Files", .{
                    .reorderable = true,
                    .auto_select_new_tabs = true,
                })) {
                    defer zgui.endTabBar();

                    for (pixi.state.open_files.items) |file, i| {
                        var open: bool = true;

                        const file_name = std.fs.path.basename(file.path);

                        zgui.pushIntId(@intCast(i32, i));
                        defer zgui.popId();

                        const label = zgui.formatZ("  {s}  {s} ", .{ pixi.fa.file_powerpoint, file_name });

                        if (zgui.beginTabItem(label, .{
                            .p_open = &open,
                            .flags = .{
                                .set_selected = pixi.state.open_file_index == i,
                                .unsaved_document = file.dirty,
                            },
                        })) {
                            zgui.endTabItem();
                        }
                        if (zgui.isItemClicked(.left)) {
                            pixi.editor.setActiveFile(i);
                        }
                        if (zgui.isItemHovered(.{})) {
                            path_hover_timer += pixi.state.gctx.stats.delta_time;

                            if (path_hover_timer >= 1.0) {
                                zgui.pushStyleVar2f(.{ .idx = zgui.StyleVar.window_padding, .v = .{ 4.0 * pixi.state.window.scale[0], 4.0 * pixi.state.window.scale[1] } });
                                defer zgui.popStyleVar(.{ .count = 1 });
                                zgui.beginTooltip();
                                defer zgui.endTooltip();
                                zgui.textColored(pixi.state.style.text_secondary.toSlice(), "{s}", .{file.path});
                            }
                        } else {
                            path_hover_timer = 0.0;
                        }

                        if (!open) {
                            pixi.editor.closeFile(i) catch unreachable;
                        }
                    }

                    // Add ruler child windows to build layout, but wait to draw to them until camera has been updated.
                    if (pixi.state.settings.show_rulers) {
                        if (zgui.beginChild("TopRuler", .{
                            .h = zgui.getTextLineHeightWithSpacing() * 1.5,
                            .border = false,
                            .flags = .{
                                .no_scrollbar = true,
                            },
                        })) {}
                        zgui.endChild();

                        if (zgui.beginChild("SideRuler", .{
                            .h = -1.0,
                            .w = zgui.getTextLineHeightWithSpacing() * 1.5,
                            .border = false,
                            .flags = .{
                                .no_scrollbar = true,
                            },
                        })) {}
                        zgui.endChild();
                        zgui.sameLine(.{});
                    }

                    var flags: zgui.WindowFlags = .{
                        .horizontal_scrollbar = true,
                    };

                    if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                        if (zgui.beginChild(file.path, .{
                            .h = 0.0,
                            .w = 0.0,
                            .border = false,
                            .flags = flags,
                        })) {
                            pixi.editor.canvas.draw(file);
                        }
                        zgui.endChild();

                        // Now add to ruler children windows, since we have updated the camera.
                        if (pixi.state.settings.show_rulers) {
                            pixi.editor.rulers.draw(file);
                        }
                    }
                }
            } else {
                const w = @intToFloat(f32, (pixi.state.background_logo.width) / 4) * pixi.state.window.scale[0];
                const h = @intToFloat(f32, (pixi.state.background_logo.height) / 4) * pixi.state.window.scale[1];
                zgui.setCursorPosX((zgui.getWindowWidth() - w) / 2);
                zgui.setCursorPosY((zgui.getWindowHeight() - h) / 2);
                zgui.image(pixi.state.gctx.lookupResource(pixi.state.background_logo.view_handle).?, .{
                    .w = w,
                    .h = h,
                    .tint_col = .{ 1.0, 1.0, 1.0, 0.25 },
                });
                const text = zgui.formatZ("Open File    {s}  ", .{pixi.fa.file});
                const size = zgui.calcTextSize(text, .{});
                zgui.setCursorPosX((zgui.getWindowWidth() - size[0]) / 2);
                zgui.textColored(pixi.state.style.text_background.toSlice(), "Open File    {s}  ", .{pixi.fa.file});
            }
            zgui.endChild();
        }

        const flipbook_height = if (pixi.state.project_folder != null or pixi.state.open_files.items.len > 0) zgui.getContentRegionAvail()[1] - pixi.state.settings.info_bar_height * pixi.state.window.scale[1] else 0.0;
        zgui.separator();

        if (zgui.beginChild("Flipbook", .{
            .w = 0.0,
            .h = flipbook_height,
            .border = false,
            .flags = .{
                .menu_bar = if (pixi.editor.getFile(pixi.state.open_file_index)) |_| true else false,
            },
        })) {
            if (pixi.editor.getFile(pixi.state.open_file_index)) |file| {
                editor.flipbook_menu.draw();

                if (zgui.beginChild("FlipbookCanvas", .{})) {
                    editor.flipbook_canvas.draw(file);
                    zgui.endChild();
                }
            }
            zgui.endChild();
        }

        if (pixi.state.project_folder != null or pixi.state.open_files.items.len > 0) {
            zgui.pushStyleColor4f(.{ .idx = zgui.StyleCol.child_bg, .c = pixi.state.style.highlight_primary.toSlice() });
            defer zgui.popStyleColor(.{ .count = 1 });
            if (zgui.beginChild("InfoBar", .{})) {
                pixi.editor.infobar.draw();
                zgui.endChild();
            }
        }
    }
    zgui.end();
}
