shader_type canvas_item;
// Hit flash: blends the drawn colour (texture × tint) towards white. Looks only.

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}
