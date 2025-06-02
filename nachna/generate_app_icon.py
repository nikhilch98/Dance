#!/usr/bin/env python3
"""
App Icon Generator for nachna Dance Workshop App
Generates a custom app icon using the app's design language and branding.
"""

from PIL import Image, ImageDraw, ImageFont
import os
import math

def create_gradient_background(size, colors):
    """Create a gradient background."""
    image = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Create diagonal gradient from top-left to bottom-right
    for y in range(size[1]):
        for x in range(size[0]):
            # Calculate position ratio (0 to 1)
            ratio = (x + y) / (size[0] + size[1])
            
            # Interpolate between colors
            r = int(colors[0][0] * (1 - ratio) + colors[1][0] * ratio)
            g = int(colors[0][1] * (1 - ratio) + colors[1][1] * ratio)
            b = int(colors[0][2] * (1 - ratio) + colors[1][2] * ratio)
            
            draw.point((x, y), (r, g, b, 255))
    
    return image

def create_dance_icon(size):
    """Create a dance-themed icon with glassmorphism effect."""
    # nachna brand colors (from design language)
    primary_color = (0, 212, 255)  # #00D4FF (cyan)
    secondary_color = (156, 39, 176)  # #9C27B0 (purple)
    
    # Create base image
    image = create_gradient_background((size, size), [primary_color, secondary_color])
    draw = ImageDraw.Draw(image)
    
    # Add glassmorphism effect with rounded corners
    corner_radius = size // 5
    
    # Create mask for rounded corners
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, size, size], corner_radius, fill=255)
    
    # Apply mask to create rounded corners
    rounded_image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    rounded_image.paste(image, (0, 0))
    rounded_image.putalpha(mask)
    
    # Add dance figure silhouette
    center_x, center_y = size // 2, size // 2
    figure_size = size // 3
    
    # Create stylized dance figure
    # Head
    head_radius = figure_size // 8
    head_x = center_x
    head_y = center_y - figure_size // 2
    
    # Body and limbs (simplified dance pose)
    body_points = [
        # Torso
        (center_x, head_y + head_radius),
        (center_x, center_y),
        
        # Left arm (raised)
        (center_x - figure_size // 4, center_y - figure_size // 4),
        (center_x - figure_size // 2, center_y - figure_size // 3),
        
        # Right arm
        (center_x + figure_size // 4, center_y - figure_size // 6),
        (center_x + figure_size // 3, center_y),
        
        # Left leg
        (center_x - figure_size // 6, center_y + figure_size // 4),
        (center_x - figure_size // 4, center_y + figure_size // 2),
        
        # Right leg
        (center_x + figure_size // 6, center_y + figure_size // 4),
        (center_x + figure_size // 3, center_y + figure_size // 2),
    ]
    
    # Draw dance figure with white color and transparency
    figure_color = (255, 255, 255, 200)
    
    # Head
    draw.ellipse([head_x - head_radius, head_y - head_radius, 
                  head_x + head_radius, head_y + head_radius], 
                 fill=figure_color)
    
    # Body lines with thickness
    line_width = max(2, size // 100)
    
    # Torso
    draw.line([body_points[0], body_points[1]], fill=figure_color, width=line_width * 2)
    
    # Arms
    draw.line([body_points[1], body_points[2]], fill=figure_color, width=line_width)
    draw.line([body_points[2], body_points[3]], fill=figure_color, width=line_width)
    draw.line([body_points[1], body_points[4]], fill=figure_color, width=line_width)
    draw.line([body_points[4], body_points[5]], fill=figure_color, width=line_width)
    
    # Legs
    draw.line([body_points[1], body_points[6]], fill=figure_color, width=line_width)
    draw.line([body_points[6], body_points[7]], fill=figure_color, width=line_width)
    draw.line([body_points[1], body_points[8]], fill=figure_color, width=line_width)
    draw.line([body_points[8], body_points[9]], fill=figure_color, width=line_width)
    
    # Add "nachna" text at bottom
    try:
        # Try to use a system font
        font_size = max(12, size // 15)
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        # Fallback to default font
        font = ImageFont.load_default()
    
    text = "nachna"
    text_bbox = draw.textbbox((0, 0), text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    
    text_x = (size - text_width) // 2
    text_y = size - text_height - size // 10
    
    # Add text with shadow effect
    shadow_offset = max(1, size // 200)
    draw.text((text_x + shadow_offset, text_y + shadow_offset), text, 
              fill=(0, 0, 0, 100), font=font)
    draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)
    
    # Add subtle highlight effect
    highlight_overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight_overlay)
    
    # Top highlight
    highlight_draw.ellipse([size // 4, size // 6, size * 3 // 4, size // 2], 
                          fill=(255, 255, 255, 30))
    
    # Blend highlight
    rounded_image = Image.alpha_composite(rounded_image, highlight_overlay)
    
    return rounded_image

def generate_ios_icons():
    """Generate all required iOS app icon sizes."""
    ios_sizes = [
        (20, "Icon-App-20x20@1x.png"),
        (40, "Icon-App-20x20@2x.png"),
        (60, "Icon-App-20x20@3x.png"),
        (29, "Icon-App-29x29@1x.png"),
        (58, "Icon-App-29x29@2x.png"),
        (87, "Icon-App-29x29@3x.png"),
        (40, "Icon-App-40x40@1x.png"),
        (80, "Icon-App-40x40@2x.png"),
        (120, "Icon-App-40x40@3x.png"),
        (120, "Icon-App-60x60@2x.png"),
        (180, "Icon-App-60x60@3x.png"),
        (76, "Icon-App-76x76@1x.png"),
        (152, "Icon-App-76x76@2x.png"),
        (167, "Icon-App-83.5x83.5@2x.png"),
        (1024, "Icon-App-1024x1024@1x.png"),
    ]
    
    output_dir = "app_icons/ios"
    os.makedirs(output_dir, exist_ok=True)
    
    print("Generating iOS app icons...")
    for size, filename in ios_sizes:
        print(f"Creating {filename} ({size}x{size})")
        icon = create_dance_icon(size)
        icon.save(os.path.join(output_dir, filename), "PNG")
    
    print(f"iOS icons saved to {output_dir}/")

def generate_android_icons():
    """Generate all required Android app icon sizes."""
    android_sizes = [
        (48, "mipmap-mdpi/ic_launcher.png"),
        (72, "mipmap-hdpi/ic_launcher.png"),
        (96, "mipmap-xhdpi/ic_launcher.png"),
        (144, "mipmap-xxhdpi/ic_launcher.png"),
        (192, "mipmap-xxxhdpi/ic_launcher.png"),
    ]
    
    print("Generating Android app icons...")
    for size, path in android_sizes:
        output_dir = f"app_icons/android/{os.path.dirname(path)}"
        os.makedirs(output_dir, exist_ok=True)
        
        filename = os.path.basename(path)
        print(f"Creating {filename} ({size}x{size})")
        icon = create_dance_icon(size)
        icon.save(os.path.join(output_dir, filename), "PNG")
    
    print("Android icons saved to app_icons/android/")

def generate_app_store_icon():
    """Generate 1024x1024 icon for App Store Connect."""
    print("Generating App Store Connect icon (1024x1024)...")
    
    output_dir = "app_icons"
    os.makedirs(output_dir, exist_ok=True)
    
    icon = create_dance_icon(1024)
    icon.save(os.path.join(output_dir, "app_store_icon_1024x1024.png"), "PNG")
    
    print("App Store icon saved to app_icons/app_store_icon_1024x1024.png")

def main():
    """Generate all app icons."""
    print("🎭 Generating nachna App Icons")
    print("=" * 40)
    
    # Generate App Store Connect icon (most important)
    generate_app_store_icon()
    
    # Generate iOS icons
    generate_ios_icons()
    
    # Generate Android icons
    generate_android_icons()
    
    print("\n✅ All app icons generated successfully!")
    print("\nNext steps:")
    print("1. Upload 'app_icons/app_store_icon_1024x1024.png' to App Store Connect")
    print("2. Replace iOS icons in 'ios/Runner/Assets.xcassets/AppIcon.appiconset/'")
    print("3. Replace Android icons in 'android/app/src/main/res/mipmap-*/'")

if __name__ == "__main__":
    main() 