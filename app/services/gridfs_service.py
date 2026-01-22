"""
GridFS service for video storage operations.

This module provides a wrapper around MongoDB GridFS for storing and
retrieving video files with support for streaming and range requests.
"""
import gridfs
from datetime import datetime
from typing import Optional, Dict, Any, Iterator, Tuple
from bson import ObjectId
from utils.utils import get_mongo_client


class GridFSService:
    """Service for GridFS video storage operations."""
    
    # Default chunk size: 255KB (MongoDB default)
    CHUNK_SIZE = 261120
    
    @staticmethod
    def get_gridfs() -> gridfs.GridFS:
        """Get GridFS instance for the dance_app database."""
        client = get_mongo_client()
        db = client["dance_app"]
        return gridfs.GridFS(db)
    
    @staticmethod
    def get_gridfs_bucket() -> gridfs.GridFSBucket:
        """Get GridFSBucket instance for streaming operations."""
        client = get_mongo_client()
        db = client["dance_app"]
        return gridfs.GridFSBucket(db)
    
    @staticmethod
    def store_video(
        video_data: bytes,
        filename: str,
        choreo_link_id: str,
        content_type: str = "video/mp4"
    ) -> str:
        """
        Store video data in GridFS.
        
        Args:
            video_data: Raw video bytes
            filename: Name for the stored file
            choreo_link_id: ID of the associated choreo_link
            content_type: MIME type of the video
            
        Returns:
            str: The GridFS file ID as string
        """
        fs = GridFSService.get_gridfs()
        
        # Store the video with metadata
        file_id = fs.put(
            video_data,
            filename=filename,
            content_type=content_type,
            chunk_size=GridFSService.CHUNK_SIZE,
            metadata={
                "choreo_link_id": ObjectId(choreo_link_id) if isinstance(choreo_link_id, str) else choreo_link_id,
                "content_type": content_type,
                "uploaded_at": datetime.utcnow()
            }
        )
        
        return str(file_id)
    
    @staticmethod
    def store_video_from_file(
        file_path: str,
        filename: str,
        choreo_link_id: str,
        content_type: str = "video/mp4"
    ) -> Tuple[str, int]:
        """
        Store video from a file path in GridFS.
        
        Args:
            file_path: Path to the video file
            filename: Name for the stored file
            choreo_link_id: ID of the associated choreo_link
            content_type: MIME type of the video
            
        Returns:
            Tuple[str, int]: The GridFS file ID as string and file size in bytes
        """
        with open(file_path, 'rb') as f:
            video_data = f.read()
        
        file_id = GridFSService.store_video(
            video_data, filename, choreo_link_id, content_type
        )
        
        return file_id, len(video_data)
    
    @staticmethod
    def get_video(file_id: str) -> Optional[bytes]:
        """
        Retrieve complete video data from GridFS.
        
        Args:
            file_id: The GridFS file ID
            
        Returns:
            Video bytes or None if not found
        """
        try:
            fs = GridFSService.get_gridfs()
            oid = ObjectId(file_id) if isinstance(file_id, str) else file_id
            
            if fs.exists(oid):
                return fs.get(oid).read()
            return None
        except Exception as e:
            print(f"Error retrieving video {file_id}: {e}")
            return None
    
    @staticmethod
    def get_video_metadata(file_id: str) -> Optional[Dict[str, Any]]:
        """
        Get video metadata from GridFS.
        
        Args:
            file_id: The GridFS file ID
            
        Returns:
            Dictionary with file metadata or None if not found
        """
        try:
            fs = GridFSService.get_gridfs()
            oid = ObjectId(file_id) if isinstance(file_id, str) else file_id
            
            if fs.exists(oid):
                grid_out = fs.get(oid)
                return {
                    "_id": str(grid_out._id),
                    "filename": grid_out.filename,
                    "length": grid_out.length,
                    "chunk_size": grid_out.chunk_size,
                    "upload_date": grid_out.upload_date,
                    "content_type": grid_out.content_type,
                    "metadata": grid_out.metadata
                }
            return None
        except Exception as e:
            print(f"Error getting video metadata {file_id}: {e}")
            return None
    
    @staticmethod
    def stream_video(
        file_id: str,
        start: int = 0,
        end: Optional[int] = None
    ) -> Iterator[bytes]:
        """
        Stream video data from GridFS with range support.
        
        Args:
            file_id: The GridFS file ID
            start: Start byte position (for range requests)
            end: End byte position (for range requests, None for end of file)
            
        Yields:
            Chunks of video data
        """
        try:
            bucket = GridFSService.get_gridfs_bucket()
            oid = ObjectId(file_id) if isinstance(file_id, str) else file_id
            
            # Open the file from GridFS
            grid_out = bucket.open_download_stream(oid)
            
            # Seek to start position if specified
            if start > 0:
                grid_out.seek(start)
            
            # Calculate how many bytes to read
            if end is not None:
                bytes_to_read = end - start + 1
            else:
                bytes_to_read = grid_out.length - start
            
            # Read in chunks - 256KB for efficient video streaming
            chunk_size = 262144  # 256KB chunks for better video performance
            bytes_read = 0
            
            while bytes_read < bytes_to_read:
                to_read = min(chunk_size, bytes_to_read - bytes_read)
                chunk = grid_out.read(to_read)
                if not chunk:
                    break
                bytes_read += len(chunk)
                yield chunk
            
            grid_out.close()
            
        except Exception as e:
            print(f"Error streaming video {file_id}: {e}")
            raise
    
    @staticmethod
    def delete_video(file_id: str) -> bool:
        """
        Delete a video from GridFS.
        
        Args:
            file_id: The GridFS file ID
            
        Returns:
            True if deleted successfully, False otherwise
        """
        try:
            fs = GridFSService.get_gridfs()
            oid = ObjectId(file_id) if isinstance(file_id, str) else file_id
            
            if fs.exists(oid):
                fs.delete(oid)
                return True
            return False
        except Exception as e:
            print(f"Error deleting video {file_id}: {e}")
            return False
    
    @staticmethod
    def video_exists(file_id: str) -> bool:
        """
        Check if a video exists in GridFS.
        
        Args:
            file_id: The GridFS file ID
            
        Returns:
            True if exists, False otherwise
        """
        try:
            fs = GridFSService.get_gridfs()
            oid = ObjectId(file_id) if isinstance(file_id, str) else file_id
            return fs.exists(oid)
        except Exception as e:
            print(f"Error checking video existence {file_id}: {e}")
            return False
    
    @staticmethod
    def get_file_length(file_id: str) -> Optional[int]:
        """
        Get the length of a video file in bytes.
        
        Args:
            file_id: The GridFS file ID
            
        Returns:
            File size in bytes or None if not found
        """
        metadata = GridFSService.get_video_metadata(file_id)
        if metadata:
            return metadata.get("length")
        return None
    
    @staticmethod
    def list_videos_by_choreo_link(choreo_link_id: str) -> list:
        """
        List all videos associated with a choreo_link.
        
        Args:
            choreo_link_id: The choreo_link document ID
            
        Returns:
            List of video metadata dictionaries
        """
        try:
            client = get_mongo_client()
            db = client["dance_app"]
            fs_files = db["fs.files"]
            
            oid = ObjectId(choreo_link_id) if isinstance(choreo_link_id, str) else choreo_link_id
            
            videos = list(fs_files.find({
                "metadata.choreo_link_id": oid
            }))
            
            return [{
                "_id": str(v["_id"]),
                "filename": v.get("filename"),
                "length": v.get("length"),
                "upload_date": v.get("uploadDate"),
                "content_type": v.get("contentType"),
                "metadata": v.get("metadata")
            } for v in videos]
            
        except Exception as e:
            print(f"Error listing videos for choreo_link {choreo_link_id}: {e}")
            return []
