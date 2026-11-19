shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float phase = 0.0;
uniform float density = 0.40;
uniform bool distant = false;
uniform bool ground_sheet = false;
uniform bool maze_haze = false;
uniform bool soft_contact = false;
uniform float warmth = 0.0;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
varying vec3 world_point;

float breeze_hash(vec2 p) {
	return fract(sin(dot(p,vec2(21.76,78.31))) * 43162.9);
}

float vapor(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0),vec2(1.0),fract(p));
	return mix(mix(breeze_hash(cell),breeze_hash(cell+vec2(1,0)),f.x),
		mix(breeze_hash(cell+vec2(0,1)),breeze_hash(cell+vec2(1,1)),f.x),f.y);
}

float contact_fade(float depth, vec2 screen_uv, mat4 inverse_projection, float fragment_z, float feather) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	#endif
	vec4 scene = inverse_projection * vec4(ndc, 1.0);
	return smoothstep(0.02, feather, fragment_z - scene.z / scene.w);
}

void vertex() {
	if (!maze_haze) {
		VERTEX.x += sin(TIME*(distant ? 0.19 : 0.53) + phase)*(distant ? 1.7 : 0.54);
		VERTEX.y += sin(TIME*0.41 + phase*1.31)*0.074;
	}
	if (distant && !soft_contact) {
		// Raise the exterior banks into the skyline's lower half.
		VERTEX.y = VERTEX.y * 0.72 + 3.9;
	}
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.16,0.98,length(p*vec2(0.96,0.92)));
	float facing = smoothstep(0.06,0.44,abs(dot(normalize(NORMAL),VIEW)));
	if (maze_haze) {
		vec2 flow = (world_point.xz - TIME * vec2(0.73, 0.17)) * vec2(0.22, 0.50);
		float banks = vapor(flow + vec2(phase, 1.7));
		float wisps = vapor(flow * vec2(1.8, 2.4) + vec2(3.8, phase));
		float cover = 0.22 + smoothstep(0.25, 0.82, banks * 0.76 + wisps * 0.24) * 0.69;
		float perimeter = 1.0 - smoothstep(0.91, 1.0, max(abs(p.x), abs(p.y)));
		float chapel = smoothstep(0.16, 0.27, length(p - vec2(0.053, 0.0)));
		float finish = mix(0.30, 1.0, smoothstep(0.04, 0.16, length(p - vec2(0.947, -0.947))));
		float distance_fade = smoothstep(0.55, 2.10, -VERTEX.z);
		float slope = abs(dot(normalize(NORMAL),VIEW));
		float depth = texture(scene_depth, SCREEN_UV).r;
		float contact = contact_fade(depth, SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX.z, 0.95);
		ALBEDO = mix(vec3(0.87, 0.79, 0.59), vec3(1.0, 0.95, 0.81), banks * 0.72);
		ALPHA = cover * perimeter * chapel * finish * contact * distance_fade * smoothstep(0.06, 0.66, slope) * density * 0.79;
	} else if (distant) {
		float t = TIME * (soft_contact ? 0.52 : 0.66);
		vec2 stream = vec2(p.x * 2.65 - t + phase, p.y * 7.6 + p.x * 0.52);
		float body = vapor(stream);
		float wisps = vapor(stream * vec2(1.9, 1.53) + vec2(3.4, phase));
		float height = p.y + (body - 0.5) * 0.41;
		float envelope = exp(-height * height * 2.9);
		float ribbon = smoothstep(0.26, 0.75, body * 0.73 + wisps * 0.27);
		ALBEDO = mix(vec3(0.77, 0.66, 0.49), vec3(1.0, 0.94, 0.80), smoothstep(0.22, 0.82, wisps));
		ALPHA = edge * facing * envelope * ribbon * density * (soft_contact ? 1.0 : 1.28);
		if (soft_contact) {
			float depth = texture(scene_depth, SCREEN_UV).r;
			ALPHA *= contact_fade(depth, SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX.z, 1.55)
				* smoothstep(1.0, 4.5, -VERTEX.z);
		}
	} else if (ground_sheet) {
		float t = TIME * 0.32 + phase;
		float body = vapor(p * vec2(2.8, 2.3) + vec2(-t, t * 0.33));
		float wisps = vapor(p * vec2(5.7, 4.1) + vec2(-t * 1.5, phase));
		ALBEDO = mix(vec3(0.88, 0.82, 0.70), vec3(1.0, 0.97, 0.87), body);
		ALPHA = edge * smoothstep(0.25, 0.78, abs(dot(normalize(NORMAL),VIEW)))
			* smoothstep(0.17, 0.79, body * 0.74 + wisps * 0.26) * density * 0.48;
	} else {
		float t = TIME * 0.38 + phase;
		float height = p.y + 0.16 + sin(p.x*2.8-t)*0.19;
		float low_band = height*2.43;
		float high_band = (height - 0.46 - 0.14*cos(p.x*4.0-t*0.71))*4.6;
		float ribbon = exp(-low_band*low_band);
		float higher = exp(-high_band*high_band)*0.58;
		float body = vapor(p*vec2(2.1,2.7) + vec2(-t*0.85,t*0.19));
		float fine = vapor(p*vec2(6.8,5.5) + vec2(-t*1.78,phase));
		float variation = smoothstep(0.12,0.78,body*0.68+fine*0.32);
		vec2 grid = UV * vec2(13.0,4.0) - vec2(t,0.10*sin(t));
		vec2 cell = floor(grid);
		float seed = breeze_hash(cell);
		vec2 point = fract(grid) - vec2(seed,0.19+breeze_hash(cell+13.0)*0.62);
		float shimmer = sin(t+seed*14.0);
		float fleck = (1.0 - smoothstep(0.025,0.19,length(point*vec2(1.06,1.35))))
			* step(0.66,seed) * (0.40+0.60*shimmer*shimmer);
		vec3 fog_color = mix(vec3(0.90,0.82,0.62),vec3(0.99,0.95,0.80),0.37+fine*0.26);
		float warm_pool = (1.0 - smoothstep(0.04, 0.79, length(p * vec2(1.0, 0.73)))) * warmth;
		fog_color = mix(fog_color, vec3(1.0, 0.91, 0.71), warm_pool * 0.55);
		ALBEDO = mix(fog_color,vec3(1.0,0.94,0.82),fleck);
		float banks = max(ribbon * mix(0.49,1.0,variation), higher * mix(0.59,0.95,1.0-variation));
		float overhead = abs((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).y);
		ALPHA = edge * facing * (1.0 - smoothstep(0.49, 0.90, overhead))
			* (banks * density + fleck * 0.10) * 0.58;
	}
}
