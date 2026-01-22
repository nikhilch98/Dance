#!/usr/bin/env python3
"""
Test script to download and optimize a single Instagram reel.

Uses yt-dlp for downloading and ffmpeg for optimization.
Shows compression statistics.

Usage:
    python scripts/test_download_reel.py <instagram_url>
    python scripts/test_download_reel.py <instagram_url> --no-optimize
    
Example:
    python scripts/test_download_reel.py "https://www.instagram.com/reel/ABC123/"

Prerequisites:
    pip install yt-dlp
    brew install ffmpeg  (or apt install ffmpeg on Linux)
"""
import sys
import os
import re
import subprocess
import shutil
import tempfile
from typing import Optional, Tuple, Dict, Any


def extract_shortcode(url: str) -> Optional[str]:
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


def check_ffmpeg() -> bool:
    """Check if ffmpeg is installed."""
    try:
        result = subprocess.run(
            ['ffmpeg', '-version'],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def check_ytdlp() -> bool:
    """Check if yt-dlp is installed."""
    try:
        result = subprocess.run(
            ['yt-dlp', '--version'],
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    except FileNotFoundError:
        return False


def download_reel(url: str, output_path: str) -> bool:
    """Download reel using yt-dlp."""
    print("Downloading with yt-dlp (using Chrome cookies)...")
    
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


def optimize_video(input_path: str, output_path: str, crf: int = 26, preset: str = 'medium') -> Tuple[bool, Optional[str]]:
    """
    Optimize video using ffmpeg.
    
    Args:
        input_path: Path to input video
        output_path: Path for optimized output
        crf: Quality level (18-28, lower = better quality, larger file)
        preset: Encoding speed (ultrafast, fast, medium, slow, veryslow)
        
    Returns:
        Tuple of (success, error_message)
    """
    try:
        result = subprocess.run([
            'ffmpeg',
            '-i', input_path,
            '-c:v', 'libx264',      # H.264 codec
            '-crf', str(crf),        # Quality-based encoding
            '-preset', preset,       # Encoding speed
            '-c:a', 'aac',           # AAC audio
            '-b:a', '96k',           # Audio bitrate
            '-movflags', '+faststart',  # Web optimization
            '-y',                    # Overwrite output
            output_path
        ], capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            return True, None
        else:
            return False, result.stderr
            
    except subprocess.TimeoutExpired:
        return False, "FFmpeg timed out"
    except FileNotFoundError:
        return False, "FFmpeg not found"
    except Exception as e:
        return False, str(e)


def format_size(size_bytes: int) -> str:
    """Format bytes as human-readable size."""
    if size_bytes >= 1024 * 1024:
        return f"{size_bytes / 1024 / 1024:.2f} MB"
    elif size_bytes >= 1024:
        return f"{size_bytes / 1024:.2f} KB"
    else:
        return f"{size_bytes} bytes"


def test_optimization_levels(input_path: str, shortcode: str) -> Dict[str, Any]:
    """Test different optimization levels and compare results."""
    original_size = os.path.getsize(input_path)
    
    print(f"\n{'='*60}")
    print("Testing different CRF levels (quality vs compression)")
    print(f"{'='*60}")
    print(f"Original size: {format_size(original_size)}")
    print(f"\nCRF values: lower = better quality, larger file")
    print(f"           higher = lower quality, smaller file")
    print(f"{'='*60}\n")
    
    results = {}
    test_crf_values = [22, 24, 26, 28, 30]
    
    with tempfile.TemporaryDirectory() as tmpdir:
        for crf in test_crf_values:
            output_path = os.path.join(tmpdir, f"test_crf{crf}.mp4")
            
            print(f"Testing CRF {crf}...", end=" ", flush=True)
            success, error = optimize_video(input_path, output_path, crf=crf, preset='medium')
            
            if success and os.path.exists(output_path):
                optimized_size = os.path.getsize(output_path)
                compression_ratio = original_size / optimized_size if optimized_size > 0 else 0
                savings = (1 - optimized_size / original_size) * 100
                
                results[crf] = {
                    "size": optimized_size,
                    "ratio": compression_ratio,
                    "savings": savings
                }
                
                print(f"{format_size(optimized_size):>10} | {compression_ratio:.2f}x | {savings:.1f}% smaller")
            else:
                print(f"Failed: {error}")
    
    return results


def main():
    # Parse arguments
    optimize = True
    test_levels = False
    url = None
    
    for arg in sys.argv[1:]:
        if arg == '--no-optimize':
            optimize = False
        elif arg == '--test-levels':
            test_levels = True
        elif not arg.startswith('--'):
            url = arg
    
    if not url:
        print("Usage: python scripts/test_download_reel.py <instagram_url> [options]")
        print("")
        print("Options:")
        print("  --no-optimize   Skip video optimization")
        print("  --test-levels   Test different CRF compression levels")
        print("")
        print('Example: python scripts/test_download_reel.py "https://www.instagram.com/reel/ABC123/"')
        sys.exit(1)
    
    # Check dependencies
    print("\nChecking dependencies...")
    
    if not check_ytdlp():
        print("❌ yt-dlp not installed. Install with: pip install yt-dlp")
        sys.exit(1)
    print("✓ yt-dlp installed")
    
    ffmpeg_available = check_ffmpeg()
    if ffmpeg_available:
        print("✓ ffmpeg installed")
    else:
        print("⚠ ffmpeg not installed (optimization disabled)")
        print("  Install with: brew install ffmpeg")
        optimize = False
    
    # Clean URL
    clean_url = url.split('?')[0]
    if not clean_url.endswith('/'):
        clean_url += '/'
    
    print(f"\n{'='*60}")
    print(f"Downloading reel from: {clean_url}")
    print(f"{'='*60}")
    
    # Extract shortcode
    shortcode = extract_shortcode(clean_url)
    if not shortcode:
        print("Error: Could not extract reel shortcode from URL")
        sys.exit(1)
    
    print(f"Shortcode: {shortcode}")
    
    # Create output directory
    output_dir = os.getcwd()
    original_filename = f"reel_{shortcode}_original.mp4"
    original_path = os.path.join(output_dir, original_filename)
    
    # Download
    print(f"\n[1/3] Downloading video...")
    success = download_reel(clean_url, original_path)
    
    if not success or not os.path.exists(original_path):
        print("\n❌ Download failed")
        sys.exit(1)
    
    original_size = os.path.getsize(original_path)
    print(f"✓ Downloaded: {format_size(original_size)}")
    
    # Test different compression levels if requested
    if test_levels and ffmpeg_available:
        test_optimization_levels(original_path, shortcode)
    
    # Optimize if enabled
    final_path = original_path
    final_filename = original_filename
    
    if optimize and ffmpeg_available:
        print(f"\n[2/3] Optimizing video (CRF=30, preset=medium)...")
        
        optimized_filename = f"reel_{shortcode}.mp4"
        optimized_path = os.path.join(output_dir, optimized_filename)
        
        success, error = optimize_video(original_path, optimized_path, crf=30, preset='medium')
        
        if success and os.path.exists(optimized_path):
            optimized_size = os.path.getsize(optimized_path)
            
            if optimized_size < original_size:
                compression_ratio = original_size / optimized_size
                savings_percent = (1 - optimized_size / original_size) * 100
                savings_bytes = original_size - optimized_size
                
                print(f"✓ Optimization successful!")
                print(f"\n{'='*60}")
                print("📊 COMPRESSION RESULTS")
                print(f"{'='*60}")
                print(f"  Original size:    {format_size(original_size)}")
                print(f"  Optimized size:   {format_size(optimized_size)}")
                print(f"  Size reduction:   {format_size(savings_bytes)} ({savings_percent:.1f}%)")
                print(f"  Compression ratio: {compression_ratio:.2f}x")
                print(f"{'='*60}")
                
                # Use optimized version
                final_path = optimized_path
                final_filename = optimized_filename
                
                # Remove original
                os.remove(original_path)
            else:
                print("⚠ Optimized file not smaller, keeping original")
                os.remove(optimized_path)
        else:
            print(f"⚠ Optimization failed: {error}")
            print("  Keeping original file")
    else:
        print(f"\n[2/3] Skipping optimization")
    
    # Final summary
    print(f"\n[3/3] Complete!")
    print(f"\n{'='*60}")
    print("📁 OUTPUT FILE")
    print(f"{'='*60}")
    print(f"  Filename: {final_filename}")
    print(f"  Size:     {format_size(os.path.getsize(final_path))}")
    print(f"  Path:     {final_path}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
