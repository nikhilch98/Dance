"""Search API routes."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.database.search import SearchOperations
from app.models.search import SearchUserResult, SearchArtistResult, SearchWorkshopResult
from app.models.workshops import WorkshopListItem
from app.services.auth import verify_token
from app.middleware.version import validate_version

router = APIRouter()


@router.get("/search/users", response_model=List[SearchUserResult])
async def search_users(
    q: str = Query(..., min_length=2, description="Search query (minimum 2 characters)"),
    limit: int = Query(20, ge=1, le=50, description="Maximum number of results"),
    user_id: str = Depends(verify_token),
    version: str = Depends(validate_version)
):
    """Search users by name.
    
    Args:
        q: Search query string
        limit: Maximum number of results to return (1-50)
        user_id: Current user ID from token
        version: API version
        
    Returns:
        List of user search results
    """
    try:
        results = SearchOperations.search_users(query=q, limit=limit)
        return results
    except Exception as e:
        print(f"User search error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Search failed"
        )


@router.get("/search/artists", response_model=List[SearchArtistResult])
async def search_artists(
    q: str = Query(..., min_length=2, description="Search query (minimum 2 characters)"),
    limit: int = Query(20, ge=1, le=50, description="Maximum number of results"),
    user_id: str = Depends(verify_token),
    version: str = Depends(validate_version)
):
    """Search artists by name or username.
    
    Args:
        q: Search query string
        limit: Maximum number of results to return (1-50)
        user_id: Current user ID from token
        version: API version
        
    Returns:
        List of artist search results
    """
    try:
        results = SearchOperations.search_artists(query=q, limit=limit)
        return results
    except Exception as e:
        print(f"Artist search error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Search failed"
        )


@router.get("/search/workshops", response_model=List[WorkshopListItem])
async def search_workshops(
    q: str = Query(..., min_length=2, description="Search query (minimum 2 characters)"),
    user_id: str = Depends(verify_token),
    version: str = Depends(validate_version)
):
    """Search workshops by song name or artist name, sorted by time.
    
    Args:
        q: Search query string
        limit: Maximum number of results to return (1-50)
        user_id: Current user ID from token
        version: API version
        
    Returns:
        List of workshop search results sorted by timestamp
    """
    try:
        results = SearchOperations.search_workshops(query=q)
        return results
    except Exception as e:
        print(f"Workshop search error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Search failed"
        ) 