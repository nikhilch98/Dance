#!/usr/bin/env python3
"""
Single Photo Resizer for App Store Connect
Takes an input photo path and resizes it to all required App Store Connect resolutions
"""

import os
import sys
from PIL import Image
from pathlib import Path

# App Store Connect required resolutions
REQUIRED_RESOLUTIONS = {
    "iphone_6_7_6_9": [
        (1320, 2868),  # iPhone 6.7" or 6.9" Portrait
        (2868, 1320),  # iPhone 6.7" or 6.9" Landscape
        (1290, 2796),  # iPhone 6.9" Portrait (alternative)
        (2796, 1290),  # iPhone 6.9" Landscape (alternative)
    ],
    "iphone_6_5": [
        (1242, 2688),  # iPhone 6.5" Portrait
        (2688, 1242),  # iPhone 6.5" Landscape
        (1284, 2778),  # iPhone 6.5" Portrait (alternative)
        (2778, 1284),  # iPhone 6.5" Landscape (alternative)
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
        print(f"❌ Error resizing {input_path}: {str(e)}")
        return False

def resize_photo_for_appstore(input_photo_path, output_base_dir="resized_screenshots"):
    """
    Resize a single photo to all App Store Connect required resolutions.
    
    Args:
        input_photo_path (str): Path to the input photo
        output_base_dir (str): Base directory for output files
    
    Returns:
        dict: Dictionary with results for each resolution
    """
    
    # Validate input file
    if not os.path.exists(input_photo_path):
        print(f"❌ Input file not found: {input_photo_path}")
        return {}
    
    # Get input file info
    input_path = Path(input_photo_path)
    filename_base = input_path.stem  # filename without extension
    
    print(f"📱 Resizing photo: {input_path.name}")
    print(f"📁 Output directory: {output_base_dir}")
    
    results = {}
    
    # Create base output directory
    os.makedirs(output_base_dir, exist_ok=True)
    
    # Resize for each category and resolution
    for category, resolutions in REQUIRED_RESOLUTIONS.items():
        results[category] = {}
        
        for width, height in resolutions:
            # Determine orientation
            orientation = "portrait" if height > width else "landscape"
            
            # Create output directory
            output_dir = os.path.join(output_base_dir, f"appstore_{category}_{width}x{height}")
            os.makedirs(output_dir, exist_ok=True)
            
            # Create output filename
            output_filename = f"{filename_base}_{width}x{height}.png"
            output_path = os.path.join(output_dir, output_filename)
            
            print(f"\n📐 Creating {width}x{height}px ({orientation})...")
            
            # Resize the image
            success = resize_image_to_exact_dimensions(
                input_photo_path, output_path, width, height
            )
            
            if success:
                print(f"✅ Saved: {output_path}")
                results[category][f"{width}x{height}"] = {
                    "success": True,
                    "path": output_path,
                    "orientation": orientation
                }
            else:
                results[category][f"{width}x{height}"] = {
                    "success": False,
                    "path": None,
                    "orientation": orientation
                }
    
    return results

def print_usage():
    """Print usage instructions."""
    print("📱 App Store Connect Photo Resizer")
    print("\nUsage:")
    print("  python resize_single_photo.py <input_photo_path> [output_directory]")
    print("\nExamples:")
    print("  python resize_single_photo.py my_screenshot.png")
    print("  python resize_single_photo.py /path/to/photo.jpg custom_output")
    print("  python resize_single_photo.py screenshots/01_studios.png")

def main():
    """Main function to handle command line arguments."""
    
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)
    
    input_photo_path = sys.argv[1]
    output_base_dir = sys.argv[2] if len(sys.argv) > 2 else "resized_screenshots"
    
    print("🔄 Starting App Store Connect photo resize...")
    
    # Resize the photo
    results = resize_photo_for_appstore(input_photo_path, output_base_dir)
    
    if not results:
        print("❌ Failed to resize photo")
        sys.exit(1)
    
    # Print summary
    print(f"\n🎉 Photo resizing complete!")
    print(f"\n📁 Output directories created in: {output_base_dir}/")
    
    total_success = 0
    total_files = 0
    
    for category, resolutions in results.items():
        print(f"\n📱 {category.replace('_', ' ').title()}:")
        for resolution, result in resolutions.items():
            total_files += 1
            if result["success"]:
                total_success += 1
                print(f"  ✅ {resolution} ({result['orientation']})")
            else:
                print(f"  ❌ {resolution} ({result['orientation']}) - Failed")
    
    print(f"\n📊 Summary: {total_success}/{total_files} files created successfully")
    
    if total_success > 0:
        print("\n📤 App Store Connect Upload Guide:")
        print("\nFor iPhone 6.7\" or 6.9\" Displays section:")
        print(f"- Use files from: {output_base_dir}/appstore_iphone_6_7_6_9_1320x2868/")
        print(f"- Alternative: {output_base_dir}/appstore_iphone_6_7_6_9_1290x2796/")
        
        print("\nFor iPhone 6.5\" Displays section:")
        print(f"- Use files from: {output_base_dir}/appstore_iphone_6_5_1242x2688/")
        print(f"- Alternative: {output_base_dir}/appstore_iphone_6_5_1284x2778/")

# Function that can be imported and used programmatically
def resize_photo(input_path, output_dir="resized_screenshots"):
    """
    Simple function to resize a photo for App Store Connect.
    
    Args:
        input_path (str): Path to input photo
        output_dir (str): Output directory (default: "resized_screenshots")
    
    Returns:
        dict: Results dictionary
    
    Example:
        from resize_single_photo import resize_photo
        results = resize_photo("my_screenshot.png", "output")
    """
    return resize_photo_for_appstore(input_path, output_dir)

if __name__ == "__main__":
    main() 