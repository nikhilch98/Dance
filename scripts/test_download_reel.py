#!/usr/bin/env python3
"""
Simple test script to download a single Instagram reel.

Uses yt-dlp (recommended) or falls back to direct scraping.

Usage:
    python scripts/test_download_reel.py <instagram_url>
    
Example:
    python scripts/test_download_reel.py "https://www.instagram.com/reel/ABC123/"

Prerequisites:
    pip install yt-dlp requests
"""
import sys
import os
import re
import subprocess
import json
import requests

def extract_shortcode(url: str) -> str:
    """Extract reel shortcode from URL."""
    patterns = [
        r'instagram\.com/reel/([A-Za-z0-9_-]+)',
        r'instagram\.com/reels/([A-Za-z0-9_-]+)',
        r'instagram\.com/p/([A-Za-z0-9_-]+)',
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


def download_with_ytdlp(url: str, output_path: str) -> bool:
    """Download using yt-dlp (most reliable)."""
    try:
        # Check if yt-dlp is installed
        result = subprocess.run(
            ['yt-dlp', '--version'],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print("yt-dlp not found")
            return False
        
        print("Using yt-dlp to download (with Chrome cookies)...")
        
        # Download the video with Chrome cookies for authentication
        result = subprocess.run(
            [
                'yt-dlp',
                '-o', output_path,
                '--no-playlist',
                '--cookies-from-browser', 'chrome',
                url
            ],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            return True
        else:
            print(f"yt-dlp error: {result.stderr}")
            return False
            
    except FileNotFoundError:
        print("yt-dlp not installed")
        return False
    except Exception as e:
        print(f"yt-dlp error: {e}")
        return False


def download_with_scraping(url: str, output_path: str) -> bool:
    """Download by scraping the page for video URL."""
    try:
        print("Trying direct scraping method...")
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
        }
        
        response = requests.get(url, headers=headers, timeout=30)
        
        if response.status_code != 200:
            print(f"Failed to fetch page: {response.status_code}")
            return False
        
        html = response.text
        
        # Try to find video URL in the page
        # Method 1: Look for video_url in JSON
        video_url_match = re.search(r'"video_url":"([^"]+)"', html)
        if video_url_match:
            video_url = video_url_match.group(1)
            video_url = video_url.replace('\\u0026', '&').replace('\\/', '/')
            print(f"Found video URL via JSON")
        else:
            # Method 2: Look for og:video meta tag
            og_video_match = re.search(r'<meta property="og:video" content="([^"]+)"', html)
            if og_video_match:
                video_url = og_video_match.group(1)
                print(f"Found video URL via og:video")
            else:
                # Method 3: Look for video src in HTML
                video_src_match = re.search(r'<video[^>]+src="([^"]+)"', html)
                if video_src_match:
                    video_url = video_src_match.group(1)
                    print(f"Found video URL via video tag")
                else:
                    print("Could not find video URL in page")
                    return False
        
        # Download the video
        print(f"Downloading video...")
        video_response = requests.get(video_url, headers=headers, stream=True, timeout=60)
        
        if video_response.status_code != 200:
            print(f"Failed to download video: {video_response.status_code}")
            return False
        
        with open(output_path, 'wb') as f:
            for chunk in video_response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        return True
        
    except Exception as e:
        print(f"Scraping error: {e}")
        return False


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/test_download_reel.py <instagram_url>")
        print('Example: python scripts/test_download_reel.py "https://www.instagram.com/reel/ABC123/"')
        sys.exit(1)
    
    instagram_url = sys.argv[1]
    
    # Clean URL (remove tracking params)
    clean_url = instagram_url.split('?')[0]
    if not clean_url.endswith('/'):
        clean_url += '/'
    
    print(f"\nDownloading reel from: {clean_url}")
    print("-" * 50)
    
    # Extract shortcode
    shortcode = extract_shortcode(clean_url)
    if not shortcode:
        print("Error: Could not extract reel shortcode from URL")
        sys.exit(1)
    
    print(f"Extracted shortcode: {shortcode}")
    
    # Output filename
    filename = f"reel_{shortcode}.mp4"
    output_path = os.path.join(os.getcwd(), filename)
    
    # Try yt-dlp first (most reliable)
    success = download_with_ytdlp(clean_url, output_path)
    
    # Fall back to scraping
    if not success:
        success = download_with_scraping(clean_url, output_path)
    
    if success and os.path.exists(output_path):
        file_size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"\nSuccess!")
        print(f"  Filename: {filename}")
        print(f"  Size: {file_size_mb:.2f} MB")
        print(f"  Saved to: {output_path}")
    else:
        print("\nError: Failed to download reel")
        print("\nTip: Install yt-dlp for better results:")
        print("  pip install yt-dlp")
        print("  or: brew install yt-dlp")
        sys.exit(1)


if __name__ == "__main__":
    main()
