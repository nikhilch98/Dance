"""Reaction API routes."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.database.reactions import ReactionOperations
from app.models.reactions import (
    EntityType,
    ReactionRequest,
    ReactionDeleteRequest,
    ReactionResponse,
    UserReactionsResponse,
    ReactionStatsResponse,
    ReactionType,
)
from app.services.auth import verify_token
from app.services.rate_limiting import check_rate_limit

router = APIRouter()


def format_reaction_response(reaction_data: dict) -> ReactionResponse:
    """Format reaction data to ReactionResponse model."""
    return ReactionResponse(
        id=str(reaction_data["_id"]),
        user_id=reaction_data["user_id"],
        entity_id=reaction_data["entity_id"],
        entity_type=EntityType(reaction_data["entity_type"]),
        reaction=reaction_data["reaction"],
        created_at=reaction_data["created_at"],
        updated_at=reaction_data["updated_at"],
        is_deleted=reaction_data.get("is_deleted", False)
    )


@router.post("/reactions", response_model=ReactionResponse)
async def create_reaction(
    reaction_data: ReactionRequest,
    user_id: str = Depends(verify_token)
):
    """Create or update a user reaction (like/follow)."""
    # Check rate limit
    if not check_rate_limit(user_id, "create_reaction"):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please try again later."
        )
    
    try:
        reaction = ReactionOperations.create_or_update_reaction(
            user_id=user_id,
            entity_id=reaction_data.entity_id,
            entity_type=reaction_data.entity_type,
            reaction=reaction_data.reaction
        )
        
        return format_reaction_response(reaction)
        
    except Exception as e:
        print(f"Error creating reaction: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create reaction"
        )


@router.delete("/reactions")
async def remove_reaction(
    reaction_data: ReactionDeleteRequest,
    user_id: str = Depends(verify_token)
):
    """Soft delete a user reaction."""
    # Check rate limit
    if not check_rate_limit(user_id, "remove_reaction"):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please try again later."
        )
    
    success = ReactionOperations.soft_delete_reaction(
        reaction_id=reaction_data.reaction_id,
        user_id=user_id
    )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reaction not found or already deleted"
        )
    
    return {"message": "Reaction removed successfully"}


@router.delete("/reactions/by-entity")
async def remove_reaction_by_entity(
    entity_id: str,
    entity_type: EntityType,
    reaction_type: ReactionType,
    user_id: str = Depends(verify_token)
):
    """Soft delete a user reaction by entity and reaction type."""
    # Check rate limit
    if not check_rate_limit(user_id, "remove_reaction"):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please try again later."
        )
    
    success = ReactionOperations.soft_delete_reaction_by_entity(
        user_id=user_id,
        entity_id=entity_id,
        entity_type=entity_type,
        reaction_type=reaction_type
    )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reaction not found or already deleted"
        )
    
    return {"message": "Reaction removed successfully"}


@router.get("/user/reactions", response_model=UserReactionsResponse)
async def get_user_reactions(user_id: str = Depends(verify_token)):
    """Get all reactions for the authenticated user."""
    # Check rate limit
    if not check_rate_limit(user_id, "get_user_reactions"):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please try again later."
        )
    
    return ReactionOperations.get_user_reactions(user_id)


@router.get("/reactions/stats/{entity_type}/{entity_id}", response_model=ReactionStatsResponse)
async def get_reaction_stats(
    entity_type: EntityType,
    entity_id: str,
    user_id: str = Depends(verify_token)
):
    """Get reaction statistics for a specific artist."""
    return ReactionOperations.get_reaction_stats(entity_id, entity_type)