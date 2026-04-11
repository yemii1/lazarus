shader_type canvas_item;

// Leemos lo que se ha dibujado justo antes de este nodo (el HUD)
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float curvature : hint_range(0.0, 1.0) = 0.08;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Aplicamos la curvatura
    vec2 centered_uv = uv * 2.0 - 1.0;
    centered_uv *= 1.0 + dot(centered_uv, centered_uv) * curvature;
    uv = centered_uv * 0.5 + 0.5;
    
    // Obtenemos el color deformado
    vec4 color = texture(SCREEN_TEXTURE, uv);
    
    // TRUCO: Si el HUD está sobre un fondo transparente en su CanvasLayer,
    // este shader deformará solo el HUD. 
    COLOR = color;
}