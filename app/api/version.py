"""Version management API routes."""

from fastapi import APIRouter, Depends, HTTPException
from app.services.auth import verify_token

router = APIRouter()

# Version configuration - can be moved to database or config later
VERSION_CONFIG = {
    "ios": {
        "minimum_version": "1.5.0",  # Force update version set to 1.5.0
        "force_update": True,       # Force update enabled
        "update_message": "A new version of Nachna is available with important updates and improvements. Please update to continue using the app.",
        "ios_app_store_url": "https://apps.apple.com/in/app/nachna-discover-dance/id6746702742"  # Replace with actual App Store ID
    },
    "android": {
        "minimum_version": "1.4.0",
        "force_update": False,
        "update_message": "A new version of Nachna is available with important updates and improvements. Please update to continue using the app.",
        "android_play_store_url": "https://play.google.com/store/apps/details?id=com.nachna.app"
    }
}

@router.get("/minimum")
async def get_minimum_version(
    platform: str = "ios",
    user_id: str = Depends(verify_token)
):
    """Get minimum required app version for the specified platform."""
    try:
        if platform not in VERSION_CONFIG:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported platform: {platform}"
            )

        return VERSION_CONFIG[platform]

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching minimum version: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Failed to fetch version information"
        )


@router.post("/update-config")
async def update_version_config(
    platform: str,
    minimum_version: str,
    force_update: bool = False,
    update_message: str = None,
    user_id: str = Depends(verify_token)
):
    """Update version configuration (admin only)."""
    from app.database.users import UserOperations

    # Check if user is admin
    user = UserOperations.get_user_by_id(user_id)
    if not user or not user.get("is_admin", False):
        raise HTTPException(
            status_code=403,
            detail="Admin access required"
        )

    try:
        if platform not in VERSION_CONFIG:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported platform: {platform}"
            )

        # Update the configuration
        VERSION_CONFIG[platform].update({
            "minimum_version": minimum_version,
            "force_update": force_update,
            "update_message": update_message or VERSION_CONFIG[platform]["update_message"]
        })

        return {
            "message": f"Version config updated for {platform}",
            "config": VERSION_CONFIG[platform]
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error updating version config: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Failed to update version configuration"
        )


@router.get("/current")
async def get_current_app_version(user_id: str = Depends(verify_token)):
    """Get current app version information."""
    try:
        return {
            "server_version": "1.5.0",
            "api_version": "2.0.0",
            "supported_platforms": list(VERSION_CONFIG.keys()),
            "version_configs": VERSION_CONFIG
        }

    except Exception as e:
        print(f"Error fetching current version: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Failed to fetch version information"
        )
