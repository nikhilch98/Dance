"""Audit logging service for tracking sensitive operations."""

import logging
from datetime import datetime
from typing import Optional, Dict, Any
from enum import Enum

from utils.utils import get_mongo_client

logger = logging.getLogger(__name__)


class AuditAction(str, Enum):
    """Audit action types."""
    # Authentication
    LOGIN_ATTEMPT = "login_attempt"
    LOGIN_SUCCESS = "login_success"
    LOGIN_FAILURE = "login_failure"
    LOGOUT = "logout"
    OTP_SENT = "otp_sent"
    OTP_VERIFIED = "otp_verified"
    OTP_FAILED = "otp_failed"

    # Profile
    PROFILE_UPDATE = "profile_update"
    PROFILE_PICTURE_UPLOAD = "profile_picture_upload"
    PROFILE_PICTURE_DELETE = "profile_picture_delete"

    # Account
    ACCOUNT_CREATED = "account_created"
    ACCOUNT_DELETED = "account_deleted"

    # Admin
    ADMIN_ACTION = "admin_action"
    ADMIN_LOGIN = "admin_login"

    # Orders
    ORDER_CREATED = "order_created"
    ORDER_PAID = "order_paid"
    ORDER_CANCELLED = "order_cancelled"

    # Device
    DEVICE_REGISTERED = "device_registered"
    DEVICE_UNREGISTERED = "device_unregistered"


class AuditService:
    """Service for logging audit events."""

    COLLECTION_NAME = "audit_logs"
    DATABASE_NAME = "dance_app"

    @classmethod
    def log(
        cls,
        action: AuditAction,
        user_id: Optional[str] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
        success: bool = True,
        error_message: Optional[str] = None
    ) -> Optional[str]:
        """
        Log an audit event.

        Args:
            action: The action being audited
            user_id: ID of the user performing the action
            ip_address: IP address of the request
            user_agent: User agent string
            details: Additional details about the action
            success: Whether the action was successful
            error_message: Error message if action failed

        Returns:
            ID of the created audit log entry, or None if logging failed
        """
        try:
            client = get_mongo_client()
            db = client[cls.DATABASE_NAME]

            audit_entry = {
                "action": action.value if isinstance(action, AuditAction) else action,
                "user_id": user_id,
                "ip_address": ip_address,
                "user_agent": user_agent,
                "details": details or {},
                "success": success,
                "error_message": error_message,
                "timestamp": datetime.utcnow()
            }

            result = db[cls.COLLECTION_NAME].insert_one(audit_entry)

            logger.debug(
                f"Audit log: {action} for user {user_id or 'anonymous'} - "
                f"{'success' if success else 'failure'}"
            )

            return str(result.inserted_id)

        except Exception as e:
            logger.error(f"Failed to create audit log: {e}")
            return None

    @classmethod
    def log_login_attempt(
        cls,
        mobile_number: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        success: bool = True,
        error_message: Optional[str] = None
    ) -> Optional[str]:
        """Log a login attempt."""
        # Mask mobile number for audit log
        masked_mobile = f"{mobile_number[:2]}****{mobile_number[-2:]}" if len(mobile_number) >= 4 else "****"

        return cls.log(
            action=AuditAction.LOGIN_SUCCESS if success else AuditAction.LOGIN_FAILURE,
            ip_address=ip_address,
            user_agent=user_agent,
            details={"mobile_number_masked": masked_mobile},
            success=success,
            error_message=error_message
        )

    @classmethod
    def log_otp_sent(
        cls,
        mobile_number: str,
        ip_address: Optional[str] = None
    ) -> Optional[str]:
        """Log OTP sent event."""
        masked_mobile = f"{mobile_number[:2]}****{mobile_number[-2:]}" if len(mobile_number) >= 4 else "****"

        return cls.log(
            action=AuditAction.OTP_SENT,
            ip_address=ip_address,
            details={"mobile_number_masked": masked_mobile},
            success=True
        )

    @classmethod
    def log_profile_update(
        cls,
        user_id: str,
        updated_fields: list,
        ip_address: Optional[str] = None
    ) -> Optional[str]:
        """Log profile update event."""
        return cls.log(
            action=AuditAction.PROFILE_UPDATE,
            user_id=user_id,
            ip_address=ip_address,
            details={"updated_fields": updated_fields},
            success=True
        )

    @classmethod
    def log_account_deletion(
        cls,
        user_id: str,
        ip_address: Optional[str] = None
    ) -> Optional[str]:
        """Log account deletion event."""
        return cls.log(
            action=AuditAction.ACCOUNT_DELETED,
            user_id=user_id,
            ip_address=ip_address,
            success=True
        )

    @classmethod
    def get_user_audit_logs(
        cls,
        user_id: str,
        limit: int = 100,
        action_filter: Optional[AuditAction] = None
    ) -> list:
        """
        Get audit logs for a specific user.

        Args:
            user_id: User ID to get logs for
            limit: Maximum number of logs to return
            action_filter: Optional filter by action type

        Returns:
            List of audit log entries
        """
        try:
            client = get_mongo_client()
            db = client[cls.DATABASE_NAME]

            query = {"user_id": user_id}
            if action_filter:
                query["action"] = action_filter.value

            cursor = db[cls.COLLECTION_NAME].find(query).sort(
                "timestamp", -1
            ).limit(limit)

            return list(cursor)

        except Exception as e:
            logger.error(f"Failed to get audit logs for user {user_id}: {e}")
            return []
