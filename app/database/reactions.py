"""Reaction database operations."""

from datetime import datetime
from typing import List, Optional
from bson import ObjectId
from fastapi import HTTPException, status

from utils.utils import get_mongo_client
from app.models.reactions import EntityType, ReactionType, UserReactionsResponse, ReactionStatsResponse


class ReactionOperations:
    """Database operations for user reactions (likes and follows) - Artist only with soft delete."""
    
    @staticmethod
    def create_or_update_reaction(user_id: str, entity_id: str, entity_type: EntityType, reaction: ReactionType) -> dict:
        """Create or update a user reaction for artists only."""
        client = get_mongo_client()
        
        # Only allow artist reactions
        if entity_type != EntityType.ARTIST:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only artist reactions are supported"
            )
        
        # Check if an active reaction already exists
        existing_active_reaction = client["dance_app"]["reactions"].find_one({
            "user_id": user_id,
            "entity_id": entity_id,
            "entity_type": entity_type.value,
            "reaction": reaction.value,
            "is_deleted": {"$ne": True}
        })
        
        if existing_active_reaction:
            # Active reaction already exists, return it
            return existing_active_reaction
        
        # Check if a soft-deleted reaction exists that we can reactivate
        existing_deleted_reaction = client["dance_app"]["reactions"].find_one({
            "user_id": user_id,
            "entity_id": entity_id,
            "entity_type": entity_type.value,
            "reaction": reaction.value,
            "is_deleted": True
        })
        
        if existing_deleted_reaction:
            # Reactivate the soft-deleted reaction
            client["dance_app"]["reactions"].update_one(
                {"_id": existing_deleted_reaction["_id"]},
                {
                    "$set": {
                        "is_deleted": False,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            # Return the updated reaction
            return client["dance_app"]["reactions"].find_one({"_id": existing_deleted_reaction["_id"]})
        
        # Create new reaction (users can have both LIKE and NOTIFY simultaneously)
        reaction_data = {
            "user_id": user_id,
            "entity_id": entity_id,
            "entity_type": entity_type.value,
            "reaction": reaction.value,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            "is_deleted": False
        }
        
        result = client["dance_app"]["reactions"].insert_one(reaction_data)
        reaction_data["_id"] = result.inserted_id
        return reaction_data
    
    @staticmethod
    def soft_delete_reaction(reaction_id: str, user_id: str) -> bool:
        """Soft delete a reaction by ID, ensuring the user owns it."""
        client = get_mongo_client()
        
        result = client["dance_app"]["reactions"].update_one(
            {
                "_id": ObjectId(reaction_id),
                "user_id": user_id,
                "is_deleted": {"$ne": True}
            },
            {
                "$set": {
                    "is_deleted": True,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        return result.modified_count > 0
    
    @staticmethod
    def get_user_reactions(user_id: str) -> UserReactionsResponse:
        """Get all active reactions for a specific user."""
        client = get_mongo_client()
        
        reactions = list(client["dance_app"]["reactions"].find({
            "user_id": user_id,
            "is_deleted": {"$ne": True}
        }))
        
        liked_artists = []
        notified_artists = []
        
        for reaction in reactions:
            if reaction["entity_type"] == EntityType.ARTIST.value:
                if reaction["reaction"] == ReactionType.LIKE.value:
                    liked_artists.append(reaction["entity_id"])
                elif reaction["reaction"] == ReactionType.NOTIFY.value:
                    notified_artists.append(reaction["entity_id"])
        
        return UserReactionsResponse(
            liked_artists=liked_artists,
            notified_artists=notified_artists
        )
    
    @staticmethod
    def get_reaction_stats(entity_id: str, entity_type: EntityType) -> ReactionStatsResponse:
        """Get reaction statistics for a specific entity (excluding deleted reactions)."""
        client = get_mongo_client()
        
        # Only allow artist reactions
        if entity_type != EntityType.ARTIST:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only artist reactions are supported"
            )
        
        pipeline = [
            {"$match": {
                "entity_id": entity_id, 
                "entity_type": entity_type.value,
                "is_deleted": {"$ne": True}
            }},
            {"$group": {
                "_id": "$reaction",
                "count": {"$sum": 1}
            }}
        ]
        
        stats = list(client["dance_app"]["reactions"].aggregate(pipeline))
        
        like_count = 0
        notify_count = 0
        
        for stat in stats:
            if stat["_id"] == ReactionType.LIKE.value:
                like_count = stat["count"]
            elif stat["_id"] == ReactionType.NOTIFY.value:
                notify_count = stat["count"]
        
        return ReactionStatsResponse(
            entity_id=entity_id,
            entity_type=entity_type,
            like_count=like_count,
            notify_count=notify_count
        )
    
    @staticmethod
    def get_notified_users_of_artist(artist_id: str) -> List[str]:
        """Get all user IDs who actively have notifications enabled for a specific artist."""
        client = get_mongo_client()
        
        notified_users = list(client["dance_app"]["reactions"].find({
            "entity_id": artist_id,
            "entity_type": EntityType.ARTIST.value,
            "reaction": ReactionType.NOTIFY.value,
            "is_deleted": {"$ne": True}
        }))
        
        return [user["user_id"] for user in notified_users]
    
    @staticmethod
    def get_user_reaction_for_entity(user_id: str, entity_id: str, entity_type: EntityType) -> Optional[dict]:
        """Get user's active reaction for a specific entity."""
        client = get_mongo_client()
        
        return client["dance_app"]["reactions"].find_one({
            "user_id": user_id,
            "entity_id": entity_id,
            "entity_type": entity_type.value,
            "is_deleted": {"$ne": True}
        })
    
    @staticmethod
    def get_total_reaction_count(reaction_type: ReactionType, entity_type: EntityType) -> int:
        """Get the total count of distinct reactions (user, entity combinations) by type."""
        client = get_mongo_client()
        
        return client["dance_app"]["reactions"].count_documents({
            "reaction": reaction_type.value,
            "entity_type": entity_type.value,
            "is_deleted": {"$ne": True}
        })