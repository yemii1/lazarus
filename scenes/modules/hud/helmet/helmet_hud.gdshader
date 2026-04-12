shader_type canvas_item;

// 1. Textura de los hijos y parámetros de visor
uniform sampler2D children_texture : hint_screen_texture, filter_linear;
uniform float curvature : hint_range(0.0, 0.1) = 0.05;

// 2. NUEVO: Parámetro para la Aberración Cromática (el usuario quiere "muy sutil")
uniform float aberration_intensity : hint_range(0.0, 0.02) = 0.002;

void fragment() {
    // 3. Coordenadas de pantalla y centrado
    vec2 uv = SCREEN_UV;
    vec2 centered_uv = uv * 2.0 - 1.0;
    
    // 4. Curvatura de lente (Barrel Distortion)
    float dist = dot(centered_uv, centered_uv);
    centered_uv *= 1.0 + dist * curvature;
    
    // 5. NUEVO: Lógica de Aberración Cromática
    // Calculamos el desplazamiento para los canales Rojo y Azul basado en la intensidad
    // y la distancia al centro.
    float aberration_offset = aberration_intensity * dist;
    
    // Muestreamos el canal Rojo un poco más afuera, el Verde al centro y el Azul más adentro.
    // Usamos centered_uv de base, que ya tiene la curvatura aplicada.
    
    // Canal Rojo
    vec2 uv_r = centered_uv * (1.0 + aberration_offset);
    uv_r = uv_r * 0.5 + 0.5;
    
    // Canal Verde (sin aberración extra, solo curvatura)
    vec2 uv_g = centered_uv * 0.5 + 0.5;
    
    // Canal Azul
    vec2 uv_b = centered_uv * (1.0 - aberration_offset);
    uv_b = uv_b * 0.5 + 0.5;
    
    // Muestreamos TEXTURE (que es children_texture en un CanvasGroup)
    // Usamos .r, .g, .b para tomar solo el canal correspondiente.
    // El canal Alpha lo tomamos del Verde para consistencia.
    vec4 hud_r = texture(children_texture, uv_r);
    vec4 hud_g = texture(children_texture, uv_g);
    vec4 hud_b = texture(children_texture, uv_b);
    
    vec4 final_color = vec4(hud_r.r, hud_g.g, hud_b.b, hud_g.a);
    
    // 6. EL TRUCO DE GODOT: Premultiplied Alpha y limpieza de bordes
    if (final_color.a > 0.0001) {
        final_color.rgb /= final_color.a;
    }
    
    // Limpieza de bordes para que no se repita la imagen
    if (uv_g.x < 0.0 || uv_g.x > 1.0 || uv_g.y < 0.0 || uv_g.y > 1.0) {
        final_color.a = 0.0;
    }
    
    COLOR = final_color;
}