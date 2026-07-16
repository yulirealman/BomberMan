shader_type canvas_item;

// ==== 1. 描边参数 ====
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // 描边颜色（默认黑色）
uniform float width : hint_range(0.0, 10.0) = 1.0;                    // 描边宽度（像素）

// ==== 2. 脚底阴影参数 ====
uniform bool enable_shadow = true;                                    // 是否开启阴影
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45); // 阴影颜色与透明度
uniform vec2 shadow_center = vec2(0.5, 0.92);                         // 阴影中心点（UV 坐标）
uniform vec2 shadow_size = vec2(0.22, 0.05);                          // 阴影尺寸（X为宽度，Y为高度）
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.6;           // 阴影边缘柔和度

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * width;
	vec4 sprite_color = texture(TEXTURE, UV);
	
	// —— 步骤 A：采样周围 8 个方向计算描边（只针对角色本体） ——
	float alpha = sprite_color.a;
	alpha += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
	alpha += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
	alpha += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
	alpha += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
	alpha += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
	alpha += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
	alpha += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
	alpha += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
	
	// —— 步骤 B：用数学椭圆公式计算脚底阴影强度 ——
	float shadow_mask = 0.0;
	if (enable_shadow) {
		vec2 diff = UV - shadow_center;
		float dist = (diff.x * diff.x) / (shadow_size.x * shadow_size.x) 
		           + (diff.y * diff.y) / (shadow_size.y * shadow_size.y);
		
		// 产生边缘柔和过渡
		shadow_mask = 1.0 - smoothstep(1.0 - shadow_softness, 1.0, dist);
	}
	
	// —— 步骤 C：图层顺序混合与最终输出 ——
	if (sprite_color.a > 0.0) {
		// 1. 最上层：角色身体（保持 Blender 导出的原本淡黄色/原色）
		COLOR = sprite_color;
	} else if (alpha > 0.0) {
		// 2. 中间层：角色黑边
		COLOR = outline_color;
	} else if (enable_shadow && shadow_mask > 0.0) {
		// 3. 最下层：脚底阴影（只画在角色外的透明区域）
		COLOR = vec4(shadow_color.rgb, shadow_color.a * shadow_mask);
	} else {
		// 4. 背景：纯透明
		COLOR = vec4(0.0);
	}
}