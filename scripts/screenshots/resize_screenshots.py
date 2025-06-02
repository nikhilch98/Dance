#!/usr/bin/env python3
"""
Screenshot Resizer for App Store Connect
Resizes existing screenshots to exact App Store Connect requirements
"""

import os
from PIL import Image
import shutil

# App Store Connect required resolutions
REQUIRED_RESOLUTIONS = {
    "iphone_6_7_6_9": [
        (1320, 2868),  # iPhone 6.7" or 6.9" Portrait
        (1290, 2796),  # iPhone 6.9" Portrait (alternative)
    ],
    "iphone_6_5": [
        (1242, 2688),  # iPhone 6.5" Portrait
        (1284, 2778),  # iPhone 6.5" Portrait (alternative)
    ]
}

def resize_image_to_exact_dimensions(input_path, output_path, target_width, target_height):
    """Resize image to exact dimensions while maintaining quality."""
    try:
        with Image.open(input_path) as img:
            # Convert to RGB if necessary
            if img.mode in ('RGBA', 'LA', 'P'):
                img = img.convert('RGB')
            
            # Get current dimensions
            current_width, current_height = img.size
            
            # Calculate aspect ratios
            current_ratio = current_width / current_height
            target_ratio = target_width / target_height
            
            if abs(current_ratio - target_ratio) < 0.01:
                # Aspect ratios are very similar, just resize
                resized_img = img.resize((target_width, target_height), Image.Resampling.LANCZOS)
            else:
                # Need to crop or pad to match aspect ratio
                if current_ratio > target_ratio:
                    # Current image is wider, crop width
                    new_width = int(current_height * target_ratio)
                    left = (current_width - new_width) // 2
                    img = img.crop((left, 0, left + new_width, current_height))
                else:
                    # Current image is taller, crop height
                    new_height = int(current_width / target_ratio)
                    top = (current_height - new_height) // 2
                    img = img.crop((0, top, current_width, top + new_height))
                
                # Now resize to exact dimensions
                resized_img = img.resize((target_width, target_height), Image.Resampling.LANCZOS)
            
            # Save with high quality
            resized_img.save(output_path, "PNG", quality=95, optimize=True)
            return True
            
    except Exception as e:
        print(f"Error resizing {input_path}: {str(e)}")
        return False

def find_source_screenshots():
    """Find existing screenshot files."""
    source_dirs = [
        "screenshots/iphone_6_5",
        "screenshots/iphone_6_9", 
        "screenshots/iphone"
    ]
    
    screenshots = []
    for dir_path in source_dirs:
        if os.path.exists(dir_path):
            for file in os.listdir(dir_path):
                if file.endswith('.png'):
                    screenshots.append(os.path.join(dir_path, file))
            break  # Use the first directory that exists
    
    return sorted(screenshots)

def resize_screenshots():
    """Resize screenshots to all required App Store Connect dimensions."""
    
    print("🔄 Resizing screenshots for App Store Connect...")
    
    # Find source screenshots
    source_screenshots = find_source_screenshots()
    
    if not source_screenshots:
        print("❌ No source screenshots found!")
        print("Expected to find screenshots in:")
        print("- screenshots/iphone_6_5/")
        print("- screenshots/iphone_6_9/")
        print("- screenshots/iphone/")
        return
    
    print(f"📱 Found {len(source_screenshots)} source screenshots")
    
    # Create output directories and resize for each required resolution
    for category, resolutions in REQUIRED_RESOLUTIONS.items():
        for i, (width, height) in enumerate(resolutions):
            # Create output directory
            output_dir = f"screenshots/appstore_{category}_{width}x{height}"
            os.makedirs(output_dir, exist_ok=True)
            
            print(f"\n📐 Creating {width}x{height}px screenshots...")
            
            # Resize each screenshot
            for j, source_path in enumerate(source_screenshots):
                # Get original filename without path
                filename = os.path.basename(source_path)
                output_path = os.path.join(output_dir, filename)
                
                success = resize_image_to_exact_dimensions(
                    source_path, output_path, width, height
                )
                
                if success:
                    print(f"✅ {filename} -> {width}x{height}px")
                else:
                    print(f"❌ Failed to resize {filename}")
    
    print(f"\n🎉 Screenshot resizing complete!")
    print("\n📁 Output directories created:")
    
    # List all created directories
    for category, resolutions in REQUIRED_RESOLUTIONS.items():
        for width, height in resolutions:
            dir_name = f"screenshots/appstore_{category}_{width}x{height}"
            if os.path.exists(dir_name):
                file_count = len([f for f in os.listdir(dir_name) if f.endswith('.png')])
                print(f"- {dir_name}/ ({file_count} files)")
    
    print("\n📤 App Store Connect Upload Guide:")
    print("\nFor iPhone 6.7\" or 6.9\" Displays section:")
    print("- Use screenshots from: appstore_iphone_6_7_6_9_1320x2868/")
    print("- Alternative: appstore_iphone_6_7_6_9_1290x2796/")
    
    print("\nFor iPhone 6.5\" Displays section:")
    print("- Use screenshots from: appstore_iphone_6_5_1242x2688/")
    print("- Alternative: appstore_iphone_6_5_1284x2778/")
    
    print("\n💡 Tips:")
    print("- Upload screenshots in order: 01_studios, 02_workshops, 03_artists")
    print("- The first 3 screenshots appear on the app installation sheet")
    print("- You can upload up to 10 screenshots per device size")

if __name__ == "__main__":
    resize_screenshots() 