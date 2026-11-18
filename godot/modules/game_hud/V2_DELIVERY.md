# Unified HUD and finish flow — 2026-11-18

Stamina display, status/notification icons and menu pointer return are superseded by STAMINA_RING_DELIVERY.md.

This is the previous delivery; older HUD reports describe superseded layouts.

## Play

Open project.godot in Godot 4.7.2 Standard and press F5. The existing selector opens all three finished mazes. Desktop starts fullscreen with a 1920×1080 logical canvas. Settings also supports 1920×1200 / 16:10 with preserved aspect ratio. This source delivery does not rebuild the deployed web export.

## Current behavior

- One GameHUD scene and runtime adapter are shared by all three mazes. Compass removed; ESC developer controls retained.
- Energy meter uses the supplied PNG, with its three small rays always visible and animated only while sprinting or boosted. Three capsule cells fill/drain smoothly. The third cell's outline is copied from the first at the same pixel scale so the line weight matches. Original PNGs are never overwritten.
- Liquid styles are previews pending the user's choice. The production shader's liquid_strength defaults to zero; ordinary yellow fill remains enabled.
- Latest supplied white-border exit/restart/settings artwork is in assets/UI/HUD/v3. Each has 64 logical pixels of visible height and a common top baseline; hit targets stay fixed while hover enlarges the artwork.
- Status icons and labels use a four-column grid aligned to the meter's left edge. Notifications are centered, 520×56, raised 44px, rounded and translucent.
- Settings: 16:9 / 16:10; Low = half-resolution render, Medium = native resolution without MSAA, High = native resolution with 2x MSAA; master volume; mouse sensitivity. Preferences are shared and stored in user://game_settings.cfg. Existing music switch and music volume remain in ESC.
- Default third-person distance 7m, pitch 0.45rad, existing FOV and wheel zoom preserved. Mouse movement controls the view; double-left-click releases the pointer, double-click blank gameplay recaptures it. HUD item double-click retains its original action. Focus loss and menus release the pointer. Supplied yellow cursor is 44px high.
- Cake and barrier boosts both use running speed regardless of sprint input, with no stamina consumption. Overlap uses the maximum multiplier. Cake remains 1.3× for 8s; barrier remains 1.35× for 3s. Stamina restoration and item capacity stay unchanged.
- Maze03 has two stored chocolate cakes: A at (20.4,0,44.4), B at (4.7,0,9.6), using the existing inventory and pickup framework.
- Algernon's deterministic target is 55.5s. Existing mixed route, hesitation points, opening burst and hidden middle segment remain. At the finish, the mouse faces back along the approach so Charlie sees the front.
- Maze01/02 start with 3,2,1,GO; movement and elapsed time stay locked before GO. Race retains its own countdown and clock.
- Charlie dances at all three finishes for 7.2s (previously 4.2s). After the dance, exploration displays 完成; Maze03 Race displays 胜利 / 失败 / 平局 from the actual result. Mouse-first does not end Charlie's run. Restart clears the poster and celebration; a two-physics-frame reset guard prevents stale exit overlap from finishing the new run.

## Files and interfaces

Presentation: GameHUD.tscn, game_hud.gd, stamina_widget.gd, energy_fill.gdshader, settings_panel.gd, notification_widget.gd, inventory_widget.gd.

Adapters: runtime.gd, game_settings.gd, mouse_look.gd, play_flow.gd, session_clock.gd. Gameplay continues to own inventory, stamina, race and sanctuary state.

Small shared hooks: scripts/maze/follow_camera.gd exported reset defaults; scripts/maze/walk_player.gd free-boost test; scripts/characters/charlie_visual.gd timed celebration; modules/maze03_final/player.gd maximum boost selection; modules/maze03_race/controller.gd finish dance/facing; modules/maze03_final/cake_items.gd shared cake host.

Raw PNGs: assets/UI/HUD/v2/originals (energy, initial menus, cursor), v3/originals (latest white menus). Derived alpha-separated parts and masks are in derived folders. tools/import-hud-v2.ps1 rebuilds those parts. Existing fonts and original icon assets remain available.

## Actual verification

Godot 4.7.2, Compatibility renderer, RTX 4060 Laptop:

- check_v2.gd: 150 checks, zero failures, actual graphical runs of all three mazes. Covers countdown locks, UI layout, pointer double-click, settings/16:10/quality/master volume, camera defaults, energy animation, real movement speed and free stamina, cake pickup/reachability, 7.2s dances, completion posters and reset.
- check_race_v2.gd: 24 checks, zero failures, three complete native graphical race runs. Mouse arrival: 55.4999976556045s in each run. Covers mouse-first clock continuation, Charlie-first victory, defeat, front-facing finish dance and restart. A separate headless run also passed; Godot's dummy renderer reports its existing custom-sampler warning only in headless mode.
- check_energy_source.gd: 359665 opaque pixels outside the changing fill mask compared; zero differences between the frame texture and rendered output. This deliberately excludes yellow interiors and the explicitly corrected third-cell artwork.
- Runtime screenshots and raw logs are local in ../.verification/unified-hud and are excluded from Git.
- Resource scan found no missing production res:// references. Two intentional test strings refer to missing.json and a regex pattern.

To run graphical checks: Godot --path godot --rendering-method gl_compatibility --fixed-fps 60 --disable-vsync --script res://tests/game_hud/check_v2.gd (from repository root). Use check_race_v2.gd for full race repetitions. Legacy v1 visual assertions in other HUD test runners refer to older layouts; these two are the current acceptance runners.

## Scope / pending

Source and assets only. Existing published browser build is unchanged. Liquid appearance awaits the user's preset selection. No new race rules, maze architecture or sanctuary behavior were introduced in this HUD update.
