"""
Video downloader service for Instagram reels.

This module provides functionality to download Instagram reels
and store them in MongoDB GridFS.

Uses yt-dlp for downloading (no login required for public content).
Includes ffmpeg optimization for smaller file sizes.
"""
import subprocess
import tempfile
import os
import re
import time
import shutil
from datetime import datetime
from typing import Optional, Dict, Any, Tuple
from bson import ObjectId
from utils.utils import get_mongo_client
from app.services.gridfs_service import GridFSService


class VideoDownloaderService:
    """Service for downloading Instagram reels and storing them in GridFS."""
    
    # Rate limiting: delay between downloads in seconds
    DOWNLOAD_DELAY = 5
    
    # Maximum video size (50MB)
    MAX_VIDEO_SIZE = 50 * 1024 * 1024
    
    # Optimization settings
    OPTIMIZE_VIDEOS = True  # Enable video optimization by default
    FFMPEG_CRF = 30  # Quality level (18-28, lower = better quality, larger file)
    FFMPEG_PRESET = 'medium'  # Speed/compression tradeoff: ultrafast, fast, medium, slow
    FFMPEG_AUDIO_BITRATE = '96k'  # Audio bitrate (96k is fine for dance videos)
    
    def __init__(self, optimize: bool = True):
        """Initialize the downloader.
        
        Args:
            optimize: Whether to optimize downloaded videos (default: True)
        """
        self.optimize = optimize
    
    @staticmethod
    def is_ffmpeg_available() -> bool:
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
    
    @staticmethod
    def optimize_video(input_path: str, output_path: str, crf: int = 26, preset: str = 'medium', audio_bitrate: str = '96k') -> Tuple[bool, Optional[str]]:
        """
        Optimize video for smaller file size with minimal quality loss.
        
        Uses H.264 encoding with CRF (Constant Rate Factor) for quality-based encoding.
        
        Args:
            input_path: Path to input video
            output_path: Path for optimized output
            crf: Quality level (18-28, lower = better quality)
            preset: Encoding speed preset (ultrafast, fast, medium, slow)
            audio_bitrate: Audio bitrate (e.g., '96k', '128k')
            
        Returns:
            Tuple of (success, error_message)
        """
        try:
            result = subprocess.run([
                'ffmpeg',
                '-i', input_path,
                '-c:v', 'libx264',      # H.264 codec (most compatible)
                '-crf', str(crf),        # Quality-based encoding
                '-preset', preset,       # Encoding speed
                '-c:a', 'aac',           # AAC audio codec
                '-b:a', audio_bitrate,   # Audio bitrate
                '-movflags', '+faststart',  # Web optimization (metadata at start)
                '-y',                    # Overwrite output
                output_path
            ], capture_output=True, text=True, timeout=300)  # 5 minute timeout
            
            if result.returncode == 0:
                return True, None
            else:
                return False, result.stderr
                
        except subprocess.TimeoutExpired:
            return False, "FFmpeg optimization timed out"
        except FileNotFoundError:
            return False, "FFmpeg not installed"
        except Exception as e:
            return False, str(e)
    
    @staticmethod
    def extract_reel_shortcode(instagram_url: str) -> Optional[str]:
        """
        Extract reel shortcode from Instagram URL.
        
        Args:
            instagram_url: Full Instagram reel URL
            
        Returns:
            Shortcode string or None if not found
        """
        # Patterns for different Instagram URL formats
        patterns = [
            r'instagram\.com/reel/([A-Za-z0-9_-]+)',
            r'instagram\.com/reels/([A-Za-z0-9_-]+)',
            r'instagram\.com/p/([A-Za-z0-9_-]+)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, instagram_url)
            if match:
                return match.group(1)
        
        return None
    
    @staticmethod
    def _clean_url(instagram_url: str) -> str:
        """Clean URL by removing tracking parameters."""
        clean_url = instagram_url.split('?')[0]
        if not clean_url.endswith('/'):
            clean_url += '/'
        return clean_url
    
    def download_reel(self, instagram_url: str, optimize: bool = None) -> Optional[Tuple[str, bytes, Dict[str, Any]]]:
        """
        Download a reel from Instagram using yt-dlp, optionally optimizing for size.
        
        Args:
            instagram_url: Instagram reel URL
            optimize: Whether to optimize the video (defaults to self.optimize)
            
        Returns:
            Tuple of (filename, video_bytes, stats) or None if download fails
            stats includes: original_size, final_size, compression_ratio, optimized
        """
        if optimize is None:
            optimize = self.optimize
            
        shortcode = self.extract_reel_shortcode(instagram_url)
        if not shortcode:
            print(f"Could not extract shortcode from URL: {instagram_url}")
            return None
        
        clean_url = self._clean_url(instagram_url)
        
        try:
            # Create temporary directory for download
            with tempfile.TemporaryDirectory() as tmpdir:
                output_template = os.path.join(tmpdir, f"reel_{shortcode}.%(ext)s")
                
                # Download using yt-dlp with Chrome cookies for authentication
                result = subprocess.run(
                    [
                        'yt-dlp',
                        '-o', output_template,
                        '--no-playlist',
                        '--quiet',
                        '--no-warnings',
                        '--cookies-from-browser', 'chrome',
                        clean_url
                    ],
                    capture_output=True,
                    text=True,
                    timeout=120  # 2 minute timeout
                )
                
                if result.returncode != 0:
                    print(f"yt-dlp error for {shortcode}: {result.stderr}")
                    return None
                
                # Find the downloaded video file
                video_file = None
                for filename in os.listdir(tmpdir):
                    if filename.endswith(('.mp4', '.webm', '.mkv')):
                        video_file = os.path.join(tmpdir, filename)
                        break
                
                if not video_file:
                    print(f"No video file found for {shortcode}")
                    return None
                
                # Get original file size
                original_size = os.path.getsize(video_file)
                
                if original_size > self.MAX_VIDEO_SIZE:
                    print(f"Video {shortcode} exceeds maximum size: {original_size} bytes")
                    return None
                
                # Stats dictionary
                stats = {
                    "original_size": original_size,
                    "final_size": original_size,
                    "compression_ratio": 1.0,
                    "optimized": False,
                    "optimization_error": None
                }
                
                final_video_file = video_file
                
                # Optimize video if enabled and ffmpeg is available
                if optimize and self.is_ffmpeg_available():
                    optimized_path = os.path.join(tmpdir, f"reel_{shortcode}_optimized.mp4")
                    
                    print(f"Optimizing video (CRF={self.FFMPEG_CRF}, preset={self.FFMPEG_PRESET})...")
                    success, error = self.optimize_video(
                        video_file,
                        optimized_path,
                        crf=self.FFMPEG_CRF,
                        preset=self.FFMPEG_PRESET,
                        audio_bitrate=self.FFMPEG_AUDIO_BITRATE
                    )
                    
                    if success and os.path.exists(optimized_path):
                        optimized_size = os.path.getsize(optimized_path)
                        
                        # Only use optimized version if it's actually smaller
                        if optimized_size < original_size:
                            final_video_file = optimized_path
                            stats["final_size"] = optimized_size
                            stats["compression_ratio"] = original_size / optimized_size
                            stats["optimized"] = True
                            print(f"Optimization successful: {original_size / 1024 / 1024:.2f}MB -> {optimized_size / 1024 / 1024:.2f}MB ({stats['compression_ratio']:.2f}x)")
                        else:
                            print(f"Optimized file not smaller, using original")
                            stats["optimization_error"] = "Optimized file not smaller than original"
                    else:
                        print(f"Optimization failed: {error}")
                        stats["optimization_error"] = error
                elif optimize and not self.is_ffmpeg_available():
                    stats["optimization_error"] = "FFmpeg not available"
                
                # Read final video data
                with open(final_video_file, 'rb') as f:
                    video_data = f.read()
                
                # Determine extension from final file
                _, ext = os.path.splitext(final_video_file)
                output_filename = f"reel_{shortcode}{ext}"
                
                return (output_filename, video_data, stats)
                
        except subprocess.TimeoutExpired:
            print(f"Download timeout for {instagram_url}")
            return None
        except FileNotFoundError:
            print("yt-dlp not installed. Install with: pip install yt-dlp")
            return None
        except Exception as e:
            print(f"Error downloading reel {instagram_url}: {e}")
            return None
    
    def download_and_store(self, choreo_link_doc: Dict[str, Any]) -> Dict[str, Any]:
        """
        Download Instagram reel and store in GridFS.
        
        Args:
            choreo_link_doc: Document from choreo_links collection
            
        Returns:
            Dict with status information:
            - success: bool
            - gridfs_file_id: str (if successful)
            - file_size: int (if successful)
            - original_size: int (before optimization)
            - compression_ratio: float (if optimized)
            - optimized: bool
            - error: str (if failed)
        """
        choreo_link_id = str(choreo_link_doc.get("_id"))
        instagram_url = choreo_link_doc.get("choreo_insta_link")
        
        if not instagram_url:
            return {
                "success": False,
                "error": "No Instagram URL in document"
            }
        
        # Download the reel (with optimization)
        result = self.download_reel(instagram_url)
        if not result:
            return {
                "success": False,
                "error": "Failed to download reel"
            }
        
        filename, video_data, stats = result
        
        try:
            # Store in GridFS
            gridfs_file_id = GridFSService.store_video(
                video_data=video_data,
                filename=filename,
                choreo_link_id=choreo_link_id,
                content_type="video/mp4"
            )
            
            return {
                "success": True,
                "gridfs_file_id": gridfs_file_id,
                "file_size": len(video_data),
                "filename": filename,
                "original_size": stats["original_size"],
                "compression_ratio": stats["compression_ratio"],
                "optimized": stats["optimized"]
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to store video: {str(e)}"
            }
    
    @staticmethod
    def get_choreo_links_collection():
        """Get the choreo_links collection."""
        client = get_mongo_client()
        return client["discovery"]["choreo_links"]
    
    @staticmethod
    def update_choreo_link_video_status(
        choreo_link_id: str,
        status: str,
        gridfs_file_id: Optional[str] = None,
        file_size: Optional[int] = None,
        error: Optional[str] = None
    ) -> bool:
        """
        Update video status fields in choreo_links document.
        
        Args:
            choreo_link_id: The choreo_link document ID
            status: Video status (pending, processing, completed, failed)
            gridfs_file_id: GridFS file ID if video was stored
            file_size: Video file size in bytes
            error: Error message if status is failed
            
        Returns:
            True if update was successful
        """
        try:
            collection = VideoDownloaderService.get_choreo_links_collection()
            oid = ObjectId(choreo_link_id) if isinstance(choreo_link_id, str) else choreo_link_id
            
            update_doc = {
                "video_status": status,
                "video_processed_at": datetime.utcnow()
            }
            
            if gridfs_file_id:
                update_doc["gridfs_file_id"] = ObjectId(gridfs_file_id) if isinstance(gridfs_file_id, str) else gridfs_file_id
            
            if file_size is not None:
                update_doc["video_file_size"] = file_size
            
            if error:
                update_doc["video_error"] = error
            else:
                # Clear any previous error
                update_doc["video_error"] = None
            
            result = collection.update_one(
                {"_id": oid},
                {"$set": update_doc}
            )
            
            return result.modified_count > 0
            
        except Exception as e:
            print(f"Error updating choreo_link video status: {e}")
            return False
    
    def process_choreo_link(self, choreo_link_doc: Dict[str, Any]) -> bool:
        """
        Process a single choreo_link document: download video and update status.
        
        Args:
            choreo_link_doc: Document from choreo_links collection
            
        Returns:
            True if processing was successful
        """
        choreo_link_id = str(choreo_link_doc.get("_id"))
        
        # Mark as processing
        self.update_choreo_link_video_status(choreo_link_id, "processing")
        
        # Download and store
        result = self.download_and_store(choreo_link_doc)
        
        if result["success"]:
            # Mark as completed
            self.update_choreo_link_video_status(
                choreo_link_id,
                "completed",
                gridfs_file_id=result["gridfs_file_id"],
                file_size=result["file_size"]
            )
            return True
        else:
            # Mark as failed
            self.update_choreo_link_video_status(
                choreo_link_id,
                "failed",
                error=result.get("error", "Unknown error")
            )
            return False
    
    @staticmethod
    def get_unprocessed_choreo_links(limit: int = 50, active_only: bool = True) -> list:
        """
        Get choreo_links that haven't been processed yet.
        Only returns links from active (non-archived) workshops by default.
        
        Args:
            limit: Maximum number of documents to return
            active_only: Only return choreo_links for active workshops (default: True)
            
        Returns:
            List of choreo_link documents
        """
        from app.database.choreo_links import ChoreoLinksOperations
        
        # Use the centralized ChoreoLinksOperations which filters by active workshops
        docs = ChoreoLinksOperations.get_unprocessed(limit=limit, active_only=active_only)
        
        # Convert back to raw format for processing (with ObjectId)
        collection = VideoDownloaderService.get_choreo_links_collection()
        result = []
        for doc in docs:
            raw_doc = collection.find_one({"_id": ObjectId(doc["_id"])})
            if raw_doc:
                result.append(raw_doc)
        
        return result
    
    @staticmethod
    def get_failed_choreo_links(limit: int = 50, active_only: bool = True) -> list:
        """
        Get choreo_links that failed processing (for retry).
        Only returns links from active (non-archived) workshops by default.
        
        Args:
            limit: Maximum number of documents to return
            active_only: Only return choreo_links for active workshops (default: True)
            
        Returns:
            List of choreo_link documents
        """
        from app.database.choreo_links import ChoreoLinksOperations
        
        # Use the centralized ChoreoLinksOperations which filters by active workshops
        docs = ChoreoLinksOperations.get_failed(limit=limit, active_only=active_only)
        
        # Convert back to raw format for processing (with ObjectId)
        collection = VideoDownloaderService.get_choreo_links_collection()
        result = []
        for doc in docs:
            raw_doc = collection.find_one({"_id": ObjectId(doc["_id"])})
            if raw_doc:
                result.append(raw_doc)
        
        return result
    
    def process_batch(self, batch_size: int = 10, include_retries: bool = False, active_only: bool = True) -> Dict[str, int]:
        """
        Process a batch of unprocessed choreo_links.
        Only processes links from active (non-archived) workshops by default.
        
        Args:
            batch_size: Number of documents to process
            include_retries: Whether to include failed documents for retry
            active_only: Only process choreo_links for active workshops (default: True)
            
        Returns:
            Dict with counts: processed, succeeded, failed
        """
        # Get unprocessed documents (only from active workshops)
        unprocessed = self.get_unprocessed_choreo_links(limit=batch_size, active_only=active_only)
        
        # Optionally include retries
        if include_retries:
            retry_limit = max(0, batch_size - len(unprocessed))
            if retry_limit > 0:
                unprocessed.extend(self.get_failed_choreo_links(limit=retry_limit, active_only=active_only))
        
        results = {
            "processed": 0,
            "succeeded": 0,
            "failed": 0
        }
        
        for doc in unprocessed:
            success = self.process_choreo_link(doc)
            results["processed"] += 1
            if success:
                results["succeeded"] += 1
            else:
                results["failed"] += 1
            
            # Rate limiting delay
            time.sleep(self.DOWNLOAD_DELAY)
        
        return results
