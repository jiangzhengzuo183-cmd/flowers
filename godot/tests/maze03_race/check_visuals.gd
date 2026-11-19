extends "res://tests/levels/check_maze_01_greybox.gd"
var race: Node
var folder := "res://../.verification/maze03-race"
func shot(id: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join(id+".png")))
func mouse_view() -> Camera3D:
 var camera := Camera3D.new()
 actor.get_parent().add_child(camera)
 camera.fov=42
 camera.make_current()
 return camera
func aim(camera: Camera3D) -> void:
 camera.look_at_from_position(race.mouse.global_position+Vector3(0.45,0.75,0.70),race.mouse.global_position+Vector3.UP*0.35)
func run() -> void:
 root.size=Vector2i(1440,1000)
 scene=load("res://scenes/levels/Maze03.tscn").instantiate()
 root.add_child(scene)
 actor=scene.get_node("%Player")
 generator=scene.get_node("%GeneratedMaze")
 race=scene.race
 await ticks(12)
 race.request_mode("Race")
 await ticks(12)
 check(race.state=="PREPARATION","Visual preparation")
 await shot("side_by_side")
 scene.play_view.set_mode(1)
 check(not scene.get_node("Toolbar").visible and race.hud.is_visible_in_tree(),"Pure play retains race HUD while hiding existing chrome")
 await shot("play_only_countdown")
 scene.play_view.set_mode(2)
 await ticks(5)
 check(race.hud.size.x>1000 and race.hud.timer.get_global_rect().end.x<=root.size.x+1,"Fullscreen race timer stays within game rectangle")
 scene.play_view.set_mode(0)
 while race.state!="RACING":await ticks(1)
 await ticks(65)
 var camera := mouse_view()
 aim(camera)
 await ticks(3)
 await shot("mouse_run_close")
 while race.hesitation_count==0:await ticks(1)
 aim(camera)
 await ticks(7)
 check(race.mouse.current_clip==&"Turn" and race.pause_remaining>0.1,"Turn animation sampled at real hesitation")
 await shot("mouse_turn_close")
 while not race.mouse_finished:await ticks(1)
 aim(camera)
 await ticks(40)
 check(race.mouse.current_clip==&"Dance" and race.state=="RACING","Dance at exit, race still running")
 await shot("mouse_dance_close")
 camera.free()
 # Capture the verified combination as a developer-only overlay, never shipped as gameplay guidance.
 scene.show_top_view()
 var line := ImmediateMesh.new()
 var paint := StandardMaterial3D.new()
 paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 paint.albedo_color=Color("177eaa")
 paint.no_depth_test=true
 line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,paint)
 for point in race.route.points:line.surface_add_vertex(point+Vector3.UP*0.2)
 line.surface_end()
 var overlay := MeshInstance3D.new()
 overlay.mesh=line
 actor.get_parent().add_child(overlay)
 await ticks(5)
 await shot("fixed_route_top")
 overlay.free()
 print("MAZE03 RACE VISUALS ","PASS" if failures==0 else "FAIL"," failures=",failures)
 scene.queue_free()
 await ticks(4)
 OS.delay_msec(150)
 await process_frame
 quit(failures)
