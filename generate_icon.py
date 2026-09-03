import math
from PIL import Image, ImageDraw

def render_icon(size=512):
    # Render at 4x supersampling for ultra smooth anti-aliased edges
    scale = 4
    canvas_size = size * scale
    img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    unit = canvas_size / 48.0
    
    # 1. Background rounded rectangle
    # rect 0 0 48 48, rx=14
    rx = 14.0 * unit
    draw.rounded_rectangle([0, 0, canvas_size, canvas_size], radius=rx, fill=(24, 26, 30, 255))
    
    center = (canvas_size / 2.0, canvas_size / 2.0)
    
    # 2. Outer circle: r=18, stroke=#262930, width=1.5
    r1 = 18.0 * unit
    w1 = max(1, int(round(1.5 * unit)))
    bbox1 = [center[0] - r1, center[1] - r1, center[0] + r1, center[1] + r1]
    draw.ellipse(bbox1, outline=(38, 41, 48, 255), width=w1)
    
    # 3. Inner circle: r=12, stroke=#F59E0B, opacity=0.25, width=1.5
    r2 = 12.0 * unit
    w2 = max(1, int(round(1.5 * unit)))
    bbox2 = [center[0] - r2, center[1] - r2, center[0] + r2, center[1] + r2]
    draw.ellipse(bbox2, outline=(245, 158, 11, int(round(255 * 0.25))), width=w2)
    
    # 4. Center circle: r=6, fill=#F59E0B
    r3 = 6.0 * unit
    bbox3 = [center[0] - r3, center[1] - r3, center[0] + r3, center[1] + r3]
    draw.ellipse(bbox3, fill=(245, 158, 11, 255))
    
    # 5. Arcs: radius = 9, width = 2.0
    # In SVG:
    # Arc 1: M 15 24 C 15 19.0294 19.0294 15 24 15 -> (15,24) to (24,15) which is from 180 deg to 270 deg (counter-clockwise/clockwise standard)
    # Arc 2: M 33 24 C 33 28.9706 28.9706 33 24 33 -> (33,24) to (24,33) which is from 0 deg to 90 deg
    r_arc = 9.0 * unit
    w_arc = max(1, int(round(2.0 * unit)))
    bbox_arc = [center[0] - r_arc, center[1] - r_arc, center[0] + r_arc, center[1] + r_arc]
    
    # In PIL draw.arc: angles in degrees clockwise, starting from positive x-axis (0 = 3 o'clock)
    # (15,24) is 9 o'clock (180 deg), (24,15) is 12 o'clock (270 deg)
    draw.arc(bbox_arc, start=180, end=270, fill=(245, 158, 11, 255), width=w_arc)
    
    # Round caps for arc 1:
    cap_r = w_arc / 2.0
    p1 = (center[0] - r_arc, center[1])
    p2 = (center[0], center[1] - r_arc)
    draw.ellipse([p1[0] - cap_r, p1[1] - cap_r, p1[0] + cap_r, p1[1] + cap_r], fill=(245, 158, 11, 255))
    draw.ellipse([p2[0] - cap_r, p2[1] - cap_r, p2[0] + cap_r, p2[1] + cap_r], fill=(245, 158, 11, 255))
    
    # (33,24) is 3 o'clock (0 deg), (24,33) is 6 o'clock (90 deg)
    draw.arc(bbox_arc, start=0, end=90, fill=(245, 158, 11, 255), width=w_arc)
    
    # Round caps for arc 2:
    p3 = (center[0] + r_arc, center[1])
    p4 = (center[0], center[1] + r_arc)
    draw.ellipse([p3[0] - cap_r, p3[1] - cap_r, p3[0] + cap_r, p3[1] + cap_r], fill=(245, 158, 11, 255))
    draw.ellipse([p4[0] - cap_r, p4[1] - cap_r, p4[0] + cap_r, p4[1] + cap_r], fill=(245, 158, 11, 255))
    
    # Downsample using high-quality Lanczos filter
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

if __name__ == '__main__':
    icon = render_icon(512)
    icon.save(r'stitch_walkie_push_to_talk_app\walkie_app_icon\vector_rendered_512.png')
    print("Successfully generated vector_rendered_512.png")
