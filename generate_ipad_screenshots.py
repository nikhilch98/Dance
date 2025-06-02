#!/usr/bin/env python3
"""
iPad Screenshot Generator for nachna App
Converts iPhone screenshots to iPad 13" Display format for App Store Connect.

iPad 13" Display Requirements:
- 2064 × 2752px (portrait)
- 2752 × 2064px (landscape)
- 2048 × 2732px (portrait) 
- 2732 × 2048px (landscape)
"""

from PIL import Image, ImageOps, ImageFilter
import os
import shutil

def create_ipad_screenshot(iphone_image_path, output_path, ipad_size, background_color=(10, 10, 15)):
    """
    Convert iPhone screenshot to iPad format by centering and adding background.
    
    Args:
        iphone_image_path: Path to source iPhone screenshot
        output_path: Path to save iPad screenshot
        ipad_size: Tuple of (width, height) for iPad
        background_color: RGB tuple for background color
    """
    # Open the iPhone screenshot
    with Image.open(iphone_image_path) as iphone_img:
        # Convert to RGBA if needed
        if iphone_img.mode != 'RGBA':
            iphone_img = iphone_img.convert('RGBA')
        
        # Create iPad-sized background
        ipad_img = Image.new('RGBA', ipad_size, background_color + (255,))
        
        # Calculate scaling to fit iPhone image while maintaining aspect ratio
        iphone_w, iphone_h = iphone_img.size
        ipad_w, ipad_h = ipad_size
        
        # Scale factor to fit within iPad screen with some padding
        scale_factor = min(
            (ipad_w * 0.85) / iphone_w,  # 85% of iPad width
            (ipad_h * 0.85) / iphone_h   # 85% of iPad height
        )
        
        # Resize iPhone image
        new_w = int(iphone_w * scale_factor)
        new_h = int(iphone_h * scale_factor)
        scaled_iphone = iphone_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Calculate position to center the iPhone screenshot
        x = (ipad_w - new_w) // 2
        y = (ipad_h - new_h) // 2
        
        # Add subtle shadow effect
        shadow = Image.new('RGBA', (new_w + 20, new_h + 20), (0, 0, 0, 0))
        shadow_overlay = Image.new('RGBA', (new_w + 20, new_h + 20), (0, 0, 0, 80))
        shadow.paste(shadow_overlay, (0, 0))
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=10))
        
        # Paste shadow first
        shadow_x = x - 10
        shadow_y = y - 5
        ipad_img.paste(shadow, (shadow_x, shadow_y), shadow)
        
        # Paste the scaled iPhone screenshot on top
        ipad_img.paste(scaled_iphone, (x, y), scaled_iphone)
        
        # Convert back to RGB for saving
        final_img = Image.new('RGB', ipad_size, background_color)
        final_img.paste(ipad_img, (0, 0), ipad_img)
        
        # Save the iPad screenshot
        final_img.save(output_path, 'PNG', quality=95, optimize=True)
        print(f"Created iPad screenshot: {output_path}")

def generate_ipad_screenshots():
    """Generate all required iPad 13" Display screenshots."""
    
    # Source iPhone screenshots directory
    source_dir = "/Users/nikhilchatragadda/Desktop/Dance/screenshots/appstore_iphone_6_5_1284x2778"
    
    # iPad 13" Display sizes
    ipad_sizes = {
        "2064x2752_portrait": (2064, 2752),
        "2752x2064_landscape": (2752, 2064),
        "2048x2732_portrait": (2048, 2732),
        "2732x2048_landscape": (2732, 2048)
    }
    
    # Output base directory
    output_base = "/Users/nikhilchatragadda/Desktop/Dance/screenshots"
    
    # Get list of iPhone screenshots
    if not os.path.exists(source_dir):
        print(f"Error: Source directory not found: {source_dir}")
        return
    
    iphone_files = [f for f in os.listdir(source_dir) if f.endswith('.png')]
    if not iphone_files:
        print(f"Error: No PNG files found in {source_dir}")
        return
    
    print(f"Found {len(iphone_files)} iPhone screenshots: {iphone_files}")
    
    # Generate screenshots for each iPad size
    for size_name, size_dims in ipad_sizes.items():
        output_dir = os.path.join(output_base, f"appstore_ipad_13_{size_name}")
        os.makedirs(output_dir, exist_ok=True)
        
        print(f"\nGenerating {size_name} ({size_dims[0]}×{size_dims[1]}) screenshots...")
        
        for iphone_file in sorted(iphone_files):
            input_path = os.path.join(source_dir, iphone_file)
            output_path = os.path.join(output_dir, iphone_file)
            
            try:
                create_ipad_screenshot(input_path, output_path, size_dims)
            except Exception as e:
                print(f"Error processing {iphone_file}: {str(e)}")
    
    print(f"\n✅ iPad screenshot generation complete!")
    print(f"\nGenerated directories:")
    for size_name in ipad_sizes.keys():
        dir_path = os.path.join(output_base, f"appstore_ipad_13_{size_name}")
        if os.path.exists(dir_path):
            file_count = len([f for f in os.listdir(dir_path) if f.endswith('.png')])
            print(f"  - {dir_path} ({file_count} files)")

def create_ipad_marketing_screenshots():
    """Create additional marketing-focused iPad screenshots with app branding."""
    
    # iPad sizes for marketing screenshots
    ipad_sizes = [
        (2064, 2752, "2064x2752_portrait"),
        (2048, 2732, "2048x2732_portrait")
    ]
    
    output_base = "/Users/nikhilchatragadda/Desktop/Dance/screenshots"
    
    for width, height, size_name in ipad_sizes:
        # Create marketing screenshot
        marketing_img = Image.new('RGB', (width, height), (10, 10, 15))
        
        # Add gradient background
        for y in range(height):
            ratio = y / height
            r = int(10 * (1 - ratio) + 15 * ratio)
            g = int(10 * (1 - ratio) + 33 * ratio)
            b = int(15 * (1 - ratio) + 62 * ratio)
            
            for x in range(width):
                marketing_img.putpixel((x, y), (r, g, b))
        
        # Save marketing screenshot
        marketing_dir = os.path.join(output_base, f"appstore_ipad_13_{size_name}")
        os.makedirs(marketing_dir, exist_ok=True)
        marketing_path = os.path.join(marketing_dir, "00_marketing.png")
        marketing_img.save(marketing_path, 'PNG', quality=95)
        print(f"Created marketing screenshot: {marketing_path}")

if __name__ == "__main__":
    print("🎭 Generating nachna iPad 13\" Display Screenshots")
    print("=" * 55)
    
    # Generate iPad screenshots from iPhone screenshots
    generate_ipad_screenshots()
    
    # Create additional marketing screenshots
    print(f"\nCreating marketing screenshots...")
    create_ipad_marketing_screenshots()
    
    print(f"\n📱 All iPad screenshots ready for App Store Connect!")
    print(f"\nUpload Instructions:")
    print(f"1. Go to App Store Connect > Your App > Screenshots")
    print(f"2. Select 'iPad 13\" Display'")
    print(f"3. Upload screenshots from the generated directories")
    print(f"4. You can use both portrait orientations (2064×2752 and 2048×2732)")
    print(f"5. Upload up to 10 screenshots total") 