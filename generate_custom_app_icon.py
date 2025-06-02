#!/usr/bin/env python3
"""
Custom App Icon Generator for nachna App
Uses the provided custom logo to create all required app icon sizes.
Zooms and fits the logo to perfectly fill the square aspect ratio without borders.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageOps
import os
import numpy as np

def remove_white_background(image, threshold=240):
    """
    Remove white background from an image and make it transparent.
    
    Args:
        image: PIL Image object
        threshold: Pixel values above this threshold will be considered white
    
    Returns:
        PIL Image with transparent background
    """
    # Convert to RGBA if not already
    if image.mode != 'RGBA':
        image = image.convert('RGBA')
    
    # Convert to numpy array for processing
    data = np.array(image)
    
    # Find white-ish pixels (all RGB values above threshold)
    white_pixels = (data[:, :, 0] > threshold) & (data[:, :, 1] > threshold) & (data[:, :, 2] > threshold)
    
    # Make white pixels transparent
    data[white_pixels] = [255, 255, 255, 0]
    
    # Convert back to PIL Image
    return Image.fromarray(data, 'RGBA')

def get_logo_bounds(image):
    """
    Get the bounding box of non-transparent/non-white content in the image.
    
    Args:
        image: PIL Image object
    
    Returns:
        Tuple of (left, top, right, bottom) bounds
    """
    # Remove white background first
    img_no_bg = remove_white_background(image)
    
    # Get the bounding box of non-transparent pixels
    bbox = img_no_bg.getbbox()
    
    if bbox:
        return bbox
    else:
        # Fallback to full image if no transparent pixels found
        return (0, 0, image.width, image.height)

def create_app_icon_zoom_fit(logo_path, output_path, size):
    """
    Create an app icon by zooming and cropping the logo to perfectly fill the square.
    No borders, no background colors - just the logo fitted to aspect ratio.
    
    Args:
        logo_path: Path to the source logo image
        output_path: Path to save the app icon
        size: Tuple of (width, height) for the icon
    """
    width, height = size
    
    # Open the logo image
    with Image.open(logo_path) as logo:
        # Remove white background
        logo_no_bg = remove_white_background(logo)
        
        # Get the bounds of the actual logo content
        bounds = get_logo_bounds(logo)
        left, top, right, bottom = bounds
        
        # Crop to the content bounds
        cropped_logo = logo_no_bg.crop(bounds)
        
        # Calculate the logo dimensions
        logo_w = right - left
        logo_h = bottom - top
        
        # Calculate scale to fill the entire icon (crop if necessary)
        scale = max(width / logo_w, height / logo_h)
        
        new_w = int(logo_w * scale)
        new_h = int(logo_h * scale)
        
        # Resize the logo
        resized_logo = cropped_logo.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Calculate crop coordinates to center the logo
        crop_x = (new_w - width) // 2
        crop_y = (new_h - height) // 2
        
        # Crop to exact icon size
        if new_w > width or new_h > height:
            final_logo = resized_logo.crop((crop_x, crop_y, crop_x + width, crop_y + height))
        else:
            # If somehow smaller, create white background and center
            final_icon = Image.new('RGBA', (width, height), (255, 255, 255, 255))
            x = (width - new_w) // 2
            y = (height - new_h) // 2
            final_icon.paste(resized_logo, (x, y), resized_logo)
            final_logo = final_icon
        
        # Convert to RGB for saving
        if final_logo.mode == 'RGBA':
            # Create white background for areas that might be transparent
            final_icon = Image.new('RGB', (width, height), (255, 255, 255))
            final_icon.paste(final_logo, (0, 0), final_logo)
        else:
            final_icon = final_logo.convert('RGB')
        
        # Save the icon
        final_icon.save(output_path, 'PNG', quality=100, optimize=True)
        return True

def create_app_icon_with_padding(logo_path, output_path, size, padding_percent=10):
    """
    Create an app icon with minimal padding (alternative version).
    
    Args:
        logo_path: Path to the source logo image
        output_path: Path to save the app icon
        size: Tuple of (width, height) for the icon
        padding_percent: Percentage of padding around the logo
    """
    width, height = size
    
    # Open the logo image
    with Image.open(logo_path) as logo:
        # Remove white background
        logo_no_bg = remove_white_background(logo)
        
        # Get the bounds of the actual logo content
        bounds = get_logo_bounds(logo)
        left, top, right, bottom = bounds
        
        # Crop to the content bounds
        cropped_logo = logo_no_bg.crop(bounds)
        
        # Calculate the logo dimensions
        logo_w = right - left
        logo_h = bottom - top
        
        # Calculate scale with padding
        padding_factor = (100 - padding_percent) / 100
        scale = min(width / logo_w, height / logo_h) * padding_factor
        
        new_w = int(logo_w * scale)
        new_h = int(logo_h * scale)
        
        # Resize the logo
        resized_logo = cropped_logo.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Create white background
        final_icon = Image.new('RGB', (width, height), (255, 255, 255))
        
        # Calculate position to center the logo
        x = (width - new_w) // 2
        y = (height - new_h) // 2
        
        # Paste the logo
        final_icon.paste(resized_logo, (x, y), resized_logo)
        
        # Save the icon
        final_icon.save(output_path, 'PNG', quality=100, optimize=True)
        return True

def generate_ios_icons_from_logo(logo_path):
    """Generate all iOS app icon sizes from the custom logo."""
    
    # iOS app icon sizes (width, height, filename)
    ios_sizes = [
        (20, 20, "Icon-App-20x20@1x.png"),
        (40, 40, "Icon-App-20x20@2x.png"),
        (60, 60, "Icon-App-20x20@3x.png"),
        (29, 29, "Icon-App-29x29@1x.png"),
        (58, 58, "Icon-App-29x29@2x.png"),
        (87, 87, "Icon-App-29x29@3x.png"),
        (40, 40, "Icon-App-40x40@1x.png"),
        (80, 80, "Icon-App-40x40@2x.png"),
        (120, 120, "Icon-App-40x40@3x.png"),
        (120, 120, "Icon-App-60x60@2x.png"),
        (180, 180, "Icon-App-60x60@3x.png"),
        (76, 76, "Icon-App-76x76@1x.png"),
        (152, 152, "Icon-App-76x76@2x.png"),
        (167, 167, "Icon-App-83.5x83.5@2x.png"),
        (1024, 1024, "Icon-App-1024x1024@1x.png"),
    ]
    
    # Create output directories
    ios_dir = "app_icons/ios_zoom_fit"
    ios_padding_dir = "app_icons/ios_with_padding"
    os.makedirs(ios_dir, exist_ok=True)
    os.makedirs(ios_padding_dir, exist_ok=True)
    
    print("Generating iOS app icons from custom logo...")
    print("Creating zoom-fit (no borders) and minimal padding versions...")
    
    for width, height, filename in ios_sizes:
        # Create zoom-fit version (fills entire square)
        zoom_fit_path = os.path.join(ios_dir, filename)
        success1 = create_app_icon_zoom_fit(logo_path, zoom_fit_path, (width, height))
        
        # Create minimal padding version (10% padding)
        padding_path = os.path.join(ios_padding_dir, filename)
        success2 = create_app_icon_with_padding(logo_path, padding_path, (width, height))
        
        if success1 and success2:
            print(f"Created {filename} ({width}x{height}) - both versions")
        else:
            print(f"Failed to create {filename}")
    
    # Create App Store Connect icon (use zoom-fit version)
    app_store_path = "app_icons/app_store_icon_1024x1024.png"
    create_app_icon_zoom_fit(logo_path, app_store_path, (1024, 1024))
    print(f"Created App Store icon: {app_store_path}")

def generate_android_icons_from_logo(logo_path):
    """Generate Android app icon sizes from the custom logo."""
    
    # Android app icon sizes
    android_sizes = [
        (48, 48, "mipmap-mdpi", "ic_launcher.png"),
        (72, 72, "mipmap-hdpi", "ic_launcher.png"),
        (96, 96, "mipmap-xhdpi", "ic_launcher.png"),
        (144, 144, "mipmap-xxhdpi", "ic_launcher.png"),
        (192, 192, "mipmap-xxxhdpi", "ic_launcher.png"),
    ]
    
    print("Generating Android app icons from custom logo...")
    
    for width, height, folder, filename in android_sizes:
        android_dir = f"app_icons/android/{folder}"
        os.makedirs(android_dir, exist_ok=True)
        
        output_path = os.path.join(android_dir, filename)
        success = create_app_icon_zoom_fit(logo_path, output_path, (width, height))
        if success:
            print(f"Created {folder}/{filename} ({width}x{height})")
        else:
            print(f"Failed to create {folder}/{filename}")

def copy_ios_icons_to_project(use_zoom_fit=True):
    """Copy the generated iOS icons to the iOS project."""
    import shutil
    
    # Choose which version to use
    if use_zoom_fit:
        source_dir = "app_icons/ios_zoom_fit"
        print("Using zoom-fit versions (no borders)...")
    else:
        source_dir = "app_icons/ios_with_padding"
        print("Using minimal padding versions...")
    
    target_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    
    if os.path.exists(source_dir) and os.path.exists(target_dir):
        print(f"Copying iOS icons to project...")
        
        # Copy all PNG files
        for filename in os.listdir(source_dir):
            if filename.endswith('.png'):
                source_path = os.path.join(source_dir, filename)
                target_path = os.path.join(target_dir, filename)
                shutil.copy2(source_path, target_path)
                print(f"Copied {filename}")
        
        print("✅ iOS icons copied to project!")
    else:
        print("Error: Source or target directory not found")

def main():
    """Main function to generate app icons from custom logo."""
    
    # Look for the logo file
    logo_candidates = ["logo.png", "nachna_logo.png", "app_logo.png"]
    logo_path = None
    
    for candidate in logo_candidates:
        if os.path.exists(candidate):
            logo_path = candidate
            break
    
    if not logo_path:
        print("❌ Error: Logo file not found!")
        print("Please save your logo as one of these files:")
        for candidate in logo_candidates:
            print(f"  - {candidate}")
        return False
    
    print(f"🎭 Generating nachna App Icons from {logo_path}")
    print("=" * 50)
    
    try:
        # Test if we can open the logo
        with Image.open(logo_path) as test_img:
            print(f"Logo size: {test_img.size}")
            print(f"Logo mode: {test_img.mode}")
        
        # Generate all icons
        generate_ios_icons_from_logo(logo_path)
        generate_android_icons_from_logo(logo_path)
        
        # Ask user which version to use or default to zoom-fit
        print("\nTwo versions created:")
        print("1. Zoom-fit (no borders, fills entire square) - RECOMMENDED")
        print("2. Minimal padding (10% padding around logo)")
        
        # Use zoom-fit version by default
        copy_ios_icons_to_project(use_zoom_fit=True)
        
        print("\n✅ All app icons generated successfully!")
        print("\nGenerated versions:")
        print("📁 app_icons/ios_zoom_fit/ - No borders, perfectly fitted")
        print("📁 app_icons/ios_with_padding/ - Minimal padding versions")
        print("📁 app_icons/android/ - Android versions")
        print("\nNext steps:")
        print("1. ✅ iOS icons automatically copied to project (zoom-fit version)")
        print("2. Upload 'app_icons/app_store_icon_1024x1024.png' to App Store Connect")
        print("3. Run 'flutter clean && flutter pub get' to refresh")
        print("4. Test with 'flutter run' to see new icons")
        print("\nNote: Zoom-fit versions fill the entire icon with no borders!")
        
        return True
        
    except Exception as e:
        print(f"❌ Error processing logo: {str(e)}")
        return False

if __name__ == "__main__":
    main() 