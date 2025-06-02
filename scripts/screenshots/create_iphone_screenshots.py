#!/usr/bin/env python3
"""
iPhone App Store Screenshot Generator for Nachna
Creates professional screenshots for App Store submission
Supports both iPhone 6.5" and 6.9" displays
"""

import os
from PIL import Image, ImageDraw, ImageFont
import requests
from io import BytesIO

# iPhone screenshot dimensions
IPHONE_SIZES = {
    "6.5": {"width": 1242, "height": 2688},  # iPhone 11 Pro, 12, 12 Pro, 13, 13 Pro, 14, 14 Pro
    "6.9": {"width": 1290, "height": 2796}   # iPhone 14 Pro Max, 15 Pro Max, 16 Pro Max
}

# Nachna brand colors (matching the actual app)
BACKGROUND_COLORS = [
    (10, 10, 15),      # Dark blue-black
    (26, 26, 46),      # Dark blue
    (22, 33, 62),      # Medium blue
    (15, 52, 96),      # Blue
]

PRIMARY_GRADIENT_START = (0, 212, 255)    # Cyan
PRIMARY_GRADIENT_END = (156, 39, 176)     # Purple
ACCENT_BLUE = (59, 130, 246)
ACCENT_GREEN = (16, 185, 129)
ACCENT_PINK = (255, 0, 110)              # Pink for artists
TEXT_WHITE = (255, 255, 255)
TEXT_SECONDARY = (255, 255, 255, 179)    # 70% opacity

def create_gradient_background(width, height, colors):
    """Create a gradient background using the brand colors."""
    image = Image.new('RGB', (width, height))
    draw = ImageDraw.Draw(image)
    
    # Create vertical gradient
    for y in range(height):
        # Calculate which colors to interpolate between
        progress = y / height
        color_index = progress * (len(colors) - 1)
        
        if color_index >= len(colors) - 1:
            color = colors[-1]
        else:
            # Interpolate between two colors
            lower_index = int(color_index)
            upper_index = lower_index + 1
            blend = color_index - lower_index
            
            color1 = colors[lower_index]
            color2 = colors[upper_index]
            
            color = tuple(int(c1 + (c2 - c1) * blend) for c1, c2 in zip(color1, color2))
        
        draw.line([(0, y), (width, y)], fill=color)
    
    return image

def add_glassmorphism_card(image, x, y, width, height, corner_radius=20):
    """Add a glassmorphism card effect to the image."""
    draw = ImageDraw.Draw(image)
    
    # Create rounded rectangle with semi-transparent white
    card_color = (255, 255, 255, 38)  # 15% opacity
    border_color = (255, 255, 255, 51)  # 20% opacity
    
    # Draw the card background (simplified rounded rectangle)
    draw.rounded_rectangle(
        [x, y, x + width, y + height],
        radius=corner_radius,
        fill=card_color[:3],  # PIL doesn't support alpha in fill
        outline=border_color[:3],
        width=2
    )

def get_font(size, bold=False):
    """Get system font with fallback."""
    try:
        if bold:
            return ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)
        else:
            return ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)
    except:
        return ImageFont.load_default()

def create_screenshot_1_studios(width, height):
    """Create Screenshot 1: Studios Screen (matching the actual app)."""
    image = create_gradient_background(width, height, BACKGROUND_COLORS)
    draw = ImageDraw.Draw(image)
    
    # Scale factors for different screen sizes
    scale = width / 1290
    
    # Header with icon and title
    header_y = int(120 * scale)
    header_font = get_font(int(28 * scale), bold=True)
    
    # Studios icon (simplified as colored rectangle)
    icon_size = int(40 * scale)
    icon_x = int(60 * scale)
    draw.rounded_rectangle(
        [icon_x, header_y, icon_x + icon_size, header_y + icon_size],
        radius=int(8 * scale),
        fill=PRIMARY_GRADIENT_START
    )
    
    # Studios title
    draw.text((icon_x + icon_size + int(15 * scale), header_y + int(5 * scale)), "Studios", fill=TEXT_WHITE, font=header_font)
    
    # Studio cards (2x2 grid)
    card_width = int((width - 180 * scale) // 2)
    card_height = int(200 * scale)
    card_spacing = int(60 * scale)
    cards_start_y = int(220 * scale)
    
    studios = [
        {"name": "Vins", "color": (255, 140, 0)},      # Orange
        {"name": "Dance Inn", "color": (255, 215, 0)},  # Gold
        {"name": "Dna", "color": (0, 255, 255)},       # Cyan
        {"name": "Manifest", "color": (255, 20, 147)}   # Deep pink
    ]
    
    for i, studio in enumerate(studios):
        row = i // 2
        col = i % 2
        
        card_x = int(60 * scale) + col * (card_width + card_spacing)
        card_y = cards_start_y + row * (card_height + card_spacing)
        
        # Card background
        add_glassmorphism_card(image, card_x, card_y, card_width, card_height, int(20 * scale))
        
        # Studio image placeholder (colored rectangle)
        img_height = int(120 * scale)
        img_margin = int(15 * scale)
        draw.rounded_rectangle(
            [card_x + img_margin, card_y + img_margin, 
             card_x + card_width - img_margin, card_y + img_margin + img_height],
            radius=int(12 * scale),
            fill=studio["color"]
        )
        
        # Studio name
        name_font = get_font(int(18 * scale), bold=True)
        name_y = card_y + img_height + int(35 * scale)
        name_bbox = draw.textbbox((0, 0), studio["name"], font=name_font)
        name_width = name_bbox[2] - name_bbox[0]
        name_x = card_x + (card_width - name_width) // 2
        draw.text((name_x, name_y), studio["name"], fill=TEXT_WHITE, font=name_font)
        
        # "Tap to explore" button
        btn_font = get_font(int(12 * scale))
        btn_y = name_y + int(35 * scale)
        btn_width = int(120 * scale)
        btn_height = int(30 * scale)
        btn_x = card_x + (card_width - btn_width) // 2
        
        draw.rounded_rectangle(
            [btn_x, btn_y, btn_x + btn_width, btn_y + btn_height],
            radius=int(8 * scale),
            fill=ACCENT_BLUE
        )
        
        btn_text = "Tap to explore"
        btn_bbox = draw.textbbox((0, 0), btn_text, font=btn_font)
        btn_text_width = btn_bbox[2] - btn_bbox[0]
        btn_text_x = btn_x + (btn_width - btn_text_width) // 2
        draw.text((btn_text_x, btn_y + int(8 * scale)), btn_text, fill=TEXT_WHITE, font=btn_font)
    
    return image

def create_screenshot_2_workshops(width, height):
    """Create Screenshot 2: Workshops Screen (matching the actual app)."""
    image = create_gradient_background(width, height, BACKGROUND_COLORS)
    draw = ImageDraw.Draw(image)
    
    # Scale factors for different screen sizes
    scale = width / 1290
    
    # Header with icon and title
    header_y = int(120 * scale)
    header_font = get_font(int(28 * scale), bold=True)
    
    # Workshops icon
    icon_size = int(40 * scale)
    icon_x = int(60 * scale)
    draw.rounded_rectangle(
        [icon_x, header_y, icon_x + icon_size, header_y + icon_size],
        radius=int(8 * scale),
        fill=ACCENT_BLUE
    )
    
    # Workshops title and count
    draw.text((icon_x + icon_size + int(15 * scale), header_y + int(5 * scale)), "Workshops", fill=TEXT_WHITE, font=header_font)
    
    # Count badge
    count_font = get_font(int(14 * scale), bold=True)
    count_text = "53 Found"
    count_width = int(100 * scale)
    count_height = int(30 * scale)
    count_x = width - int(60 * scale) - count_width
    count_y = header_y + int(5 * scale)
    
    draw.rounded_rectangle(
        [count_x, count_y, count_x + count_width, count_y + count_height],
        radius=int(15 * scale),
        fill=ACCENT_BLUE
    )
    
    count_bbox = draw.textbbox((0, 0), count_text, font=count_font)
    count_text_width = count_bbox[2] - count_bbox[0]
    count_text_x = count_x + (count_width - count_text_width) // 2
    draw.text((count_text_x, count_y + int(7 * scale)), count_text, fill=TEXT_WHITE, font=count_font)
    
    # Filter buttons
    filter_y = int(200 * scale)
    filter_width = int(100 * scale)
    filter_height = int(35 * scale)
    filter_spacing = int(20 * scale)
    
    filters = [
        {"text": "Date", "color": ACCENT_GREEN},
        {"text": "Artist", "color": ACCENT_PINK},
        {"text": "Studio", "color": PRIMARY_GRADIENT_END}
    ]
    
    for i, filter_item in enumerate(filters):
        filter_x = int(60 * scale) + i * (filter_width + filter_spacing)
        
        draw.rounded_rectangle(
            [filter_x, filter_y, filter_x + filter_width, filter_y + filter_height],
            radius=int(17 * scale),
            fill=filter_item["color"]
        )
        
        filter_font = get_font(int(14 * scale), bold=True)
        filter_bbox = draw.textbbox((0, 0), filter_item["text"], font=filter_font)
        filter_text_width = filter_bbox[2] - filter_bbox[0]
        filter_text_x = filter_x + (filter_width - filter_text_width) // 2
        draw.text((filter_text_x, filter_y + int(10 * scale)), filter_item["text"], fill=TEXT_WHITE, font=filter_font)
    
    # Workshop cards
    card_width = width - int(120 * scale)
    card_height = int(120 * scale)
    card_x = int(60 * scale)
    cards_start_y = int(280 * scale)
    
    workshops = [
        {
            "artist": "Ritu",
            "song": "Gun Guna Re",
            "studio": "Vins",
            "time": "12 PM",
            "date": "31st May (Sat)",
            "color": ACCENT_BLUE
        },
        {
            "artist": "Naeem Patel",
            "song": "Bang Bang",
            "studio": "Vins",
            "time": "2 PM",
            "date": "31st May (Sat)",
            "color": ACCENT_GREEN
        },
        {
            "artist": "Radhika Warikoo",
            "song": "O Rangrez",
            "studio": "Manifest",
            "time": "2-4 PM",
            "date": "31st May (Sat)",
            "color": ACCENT_PINK
        },
        {
            "artist": "Rahul Matta",
            "song": "Hm Hm Hm",
            "studio": "Dance Inn",
            "time": "3-5 PM",
            "date": "31st May (Sat)",
            "color": PRIMARY_GRADIENT_END
        }
    ]
    
    for i, workshop in enumerate(workshops):
        card_y = cards_start_y + i * (card_height + int(20 * scale))
        
        # Card background
        add_glassmorphism_card(image, card_x, card_y, card_width, card_height, int(20 * scale))
        
        # Artist name
        artist_font = get_font(int(20 * scale), bold=True)
        draw.text((card_x + int(20 * scale), card_y + int(15 * scale)), workshop["artist"], fill=TEXT_WHITE, font=artist_font)
        
        # Date badge
        date_width = int(140 * scale)
        date_height = int(25 * scale)
        date_x = card_x + card_width - date_width - int(20 * scale)
        date_y = card_y + int(15 * scale)
        
        draw.rounded_rectangle(
            [date_x, date_y, date_x + date_width, date_y + date_height],
            radius=int(12 * scale),
            fill=workshop["color"]
        )
        
        date_font = get_font(int(12 * scale), bold=True)
        date_bbox = draw.textbbox((0, 0), workshop["date"], font=date_font)
        date_text_width = date_bbox[2] - date_bbox[0]
        date_text_x = date_x + (date_width - date_text_width) // 2
        draw.text((date_text_x, date_y + int(6 * scale)), workshop["date"], fill=TEXT_WHITE, font=date_font)
        
        # Song name
        song_font = get_font(int(16 * scale), bold=True)
        draw.text((card_x + int(20 * scale), card_y + int(45 * scale)), workshop["song"], fill=workshop["color"], font=song_font)
        
        # Studio and time
        details_font = get_font(int(14 * scale))
        draw.text((card_x + int(20 * scale), card_y + int(70 * scale)), f"🏢 {workshop['studio']}", fill=TEXT_SECONDARY[:3], font=details_font)
        draw.text((card_x + int(20 * scale), card_y + int(90 * scale)), f"🕐 {workshop['time']}", fill=TEXT_SECONDARY[:3], font=details_font)
        
        # Register button
        btn_width = int(80 * scale)
        btn_height = int(30 * scale)
        btn_x = card_x + card_width - btn_width - int(20 * scale)
        btn_y = card_y + card_height - btn_height - int(15 * scale)
        
        draw.rounded_rectangle(
            [btn_x, btn_y, btn_x + btn_width, btn_y + btn_height],
            radius=int(8 * scale),
            fill=workshop["color"]
        )
        
        btn_font = get_font(int(12 * scale), bold=True)
        btn_text = "Register"
        btn_bbox = draw.textbbox((0, 0), btn_text, font=btn_font)
        btn_text_width = btn_bbox[2] - btn_bbox[0]
        btn_text_x = btn_x + (btn_width - btn_text_width) // 2
        draw.text((btn_text_x, btn_y + int(8 * scale)), btn_text, fill=TEXT_WHITE, font=btn_font)
    
    return image

def create_screenshot_3_artists(width, height):
    """Create Screenshot 3: Artists Screen (matching the actual app)."""
    image = create_gradient_background(width, height, BACKGROUND_COLORS)
    draw = ImageDraw.Draw(image)
    
    # Scale factors for different screen sizes
    scale = width / 1290
    
    # Header with icon and title
    header_y = int(120 * scale)
    header_font = get_font(int(28 * scale), bold=True)
    
    # Artists icon
    icon_size = int(40 * scale)
    icon_x = int(60 * scale)
    draw.rounded_rectangle(
        [icon_x, header_y, icon_x + icon_size, header_y + icon_size],
        radius=int(8 * scale),
        fill=ACCENT_PINK
    )
    
    # Artists title and count
    draw.text((icon_x + icon_size + int(15 * scale), header_y + int(5 * scale)), "Artists", fill=TEXT_WHITE, font=header_font)
    
    # Count badge
    count_font = get_font(int(14 * scale), bold=True)
    count_text = "21 Found"
    count_width = int(100 * scale)
    count_height = int(30 * scale)
    count_x = width - int(60 * scale) - count_width
    count_y = header_y + int(5 * scale)
    
    draw.rounded_rectangle(
        [count_x, count_y, count_x + count_width, count_y + count_height],
        radius=int(15 * scale),
        fill=ACCENT_PINK
    )
    
    count_bbox = draw.textbbox((0, 0), count_text, font=count_font)
    count_text_width = count_bbox[2] - count_bbox[0]
    count_text_x = count_x + (count_width - count_text_width) // 2
    draw.text((count_text_x, count_y + int(7 * scale)), count_text, fill=TEXT_WHITE, font=count_font)
    
    # Search bar
    search_y = int(200 * scale)
    search_height = int(50 * scale)
    add_glassmorphism_card(image, int(60 * scale), search_y, width - int(120 * scale), search_height, int(25 * scale))
    
    # Search icon and text
    search_font = get_font(int(16 * scale))
    draw.text((int(100 * scale), search_y + int(15 * scale)), "🔍 Search for your favorite artists...", fill=TEXT_SECONDARY[:3], font=search_font)
    
    # Artist cards (2x3 grid)
    card_width = int((width - 180 * scale) // 2)
    card_height = int(200 * scale)
    card_spacing = int(60 * scale)
    cards_start_y = int(300 * scale)
    
    artists = [
        {"name": "Aanchal Chandna", "color": (255, 100, 150)},
        {"name": "Aditya Tripathi", "color": (100, 200, 255)},
        {"name": "Akky Chauhan", "color": (255, 180, 100)},
        {"name": "Akshay Kundu", "color": (150, 255, 150)},
        {"name": "Ananya Gupta", "color": (200, 150, 255)},
        {"name": "Priya Sharma", "color": (255, 200, 200)}
    ]
    
    for i, artist in enumerate(artists[:6]):  # Show only 6 artists
        row = i // 2
        col = i % 2
        
        card_x = int(60 * scale) + col * (card_width + card_spacing)
        card_y = cards_start_y + row * (card_height + card_spacing)
        
        # Card background
        add_glassmorphism_card(image, card_x, card_y, card_width, card_height, int(20 * scale))
        
        # Artist image placeholder (circular)
        img_radius = int(50 * scale)
        img_center_x = card_x + card_width // 2
        img_center_y = card_y + int(70 * scale)
        
        draw.ellipse(
            [img_center_x - img_radius, img_center_y - img_radius,
             img_center_x + img_radius, img_center_y + img_radius],
            fill=artist["color"]
        )
        
        # Artist name
        name_font = get_font(int(16 * scale), bold=True)
        name_y = img_center_y + img_radius + int(20 * scale)
        name_bbox = draw.textbbox((0, 0), artist["name"], font=name_font)
        name_width = name_bbox[2] - name_bbox[0]
        name_x = card_x + (card_width - name_width) // 2
        draw.text((name_x, name_y), artist["name"], fill=TEXT_WHITE, font=name_font)
        
        # "View workshops" button
        btn_font = get_font(int(12 * scale))
        btn_y = name_y + int(30 * scale)
        btn_width = int(120 * scale)
        btn_height = int(30 * scale)
        btn_x = card_x + (card_width - btn_width) // 2
        
        draw.rounded_rectangle(
            [btn_x, btn_y, btn_x + btn_width, btn_y + btn_height],
            radius=int(8 * scale),
            fill=ACCENT_PINK
        )
        
        btn_text = "View workshops"
        btn_bbox = draw.textbbox((0, 0), btn_text, font=btn_font)
        btn_text_width = btn_bbox[2] - btn_bbox[0]
        btn_text_x = btn_x + (btn_width - btn_text_width) // 2
        draw.text((btn_text_x, btn_y + int(8 * scale)), btn_text, fill=TEXT_WHITE, font=btn_font)
    
    return image

def save_screenshots():
    """Generate and save all iPhone screenshots for both sizes."""
    
    print("🎨 Generating iPhone App Store screenshots for Nachna...")
    
    for size_name, dimensions in IPHONE_SIZES.items():
        width = dimensions["width"]
        height = dimensions["height"]
        
        output_dir = f"screenshots/iphone_{size_name.replace('.', '_')}"
        os.makedirs(output_dir, exist_ok=True)
        
        print(f"\n📱 Creating {size_name}\" iPhone screenshots ({width}x{height}px)...")
        
        # Generate screenshots
        screenshots = [
            ("01_studios", create_screenshot_1_studios(width, height)),
            ("02_workshops", create_screenshot_2_workshops(width, height)),
            ("03_artists", create_screenshot_3_artists(width, height)),
        ]
        
        for filename, screenshot in screenshots:
            filepath = os.path.join(output_dir, f"{filename}.png")
            screenshot.save(filepath, "PNG", quality=95)
            print(f"✅ Saved: {filepath}")
            print(f"   Size: {screenshot.size[0]}x{screenshot.size[1]}px")
    
    print(f"\n🎉 All screenshots saved!")
    print("\n📱 iPhone screenshots ready for App Store Connect!")
    print("\nDirectories created:")
    print("- screenshots/iphone_6_5/ (iPhone 6.5\" Display)")
    print("- screenshots/iphone_6_9/ (iPhone 6.9\" Display)")
    print("\nNext steps:")
    print("1. Upload the appropriate screenshots to App Store Connect")
    print("2. Use 6.5\" screenshots for iPhone 6.5\" Display section")
    print("3. Use 6.9\" screenshots for iPhone 6.9\" Display section")
    print("4. The first 3 screenshots will appear on the app installation sheet")

if __name__ == "__main__":
    save_screenshots() 