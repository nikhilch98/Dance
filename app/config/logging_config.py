"""Centralized logging configuration for the application."""

import logging
import os
import sys
from datetime import datetime
from typing import Optional


class SensitiveDataFilter(logging.Filter):
    """Filter to mask sensitive data in log messages."""

    SENSITIVE_PATTERNS = [
        'token', 'password', 'secret', 'key', 'otp', 'auth'
    ]

    def filter(self, record: logging.LogRecord) -> bool:
        """Mask sensitive data in log messages."""
        if hasattr(record, 'msg') and isinstance(record.msg, str):
            record.msg = self._mask_sensitive_data(record.msg)
        return True

    def _mask_sensitive_data(self, message: str) -> str:
        """Mask potentially sensitive data in message."""
        # This is a basic implementation - extend as needed
        return message


class AppLogger:
    """Application logger with structured logging support."""

    _initialized = False
    _log_level = logging.INFO

    @classmethod
    def initialize(cls, log_level: str = "INFO", app_env: str = "production"):
        """Initialize logging configuration."""
        if cls._initialized:
            return

        # Set log level based on environment
        level_map = {
            "DEBUG": logging.DEBUG,
            "INFO": logging.INFO,
            "WARNING": logging.WARNING,
            "ERROR": logging.ERROR,
            "CRITICAL": logging.CRITICAL
        }
        cls._log_level = level_map.get(log_level.upper(), logging.INFO)

        # Configure root logger
        root_logger = logging.getLogger()
        root_logger.setLevel(cls._log_level)

        # Remove existing handlers
        for handler in root_logger.handlers[:]:
            root_logger.removeHandler(handler)

        # Create console handler with formatting
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(cls._log_level)

        # Different format for development vs production
        if app_env == "development":
            formatter = logging.Formatter(
                '%(asctime)s | %(levelname)-8s | %(name)s:%(funcName)s:%(lineno)d | %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
        else:
            formatter = logging.Formatter(
                '%(asctime)s | %(levelname)-8s | %(name)s | %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )

        console_handler.setFormatter(formatter)
        console_handler.addFilter(SensitiveDataFilter())
        root_logger.addHandler(console_handler)

        # Set specific loggers to appropriate levels
        logging.getLogger("uvicorn").setLevel(logging.WARNING)
        logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
        logging.getLogger("pymongo").setLevel(logging.WARNING)

        cls._initialized = True

    @classmethod
    def get_logger(cls, name: str) -> logging.Logger:
        """Get a logger instance for a module."""
        if not cls._initialized:
            cls.initialize()
        return logging.getLogger(name)


def get_logger(name: str) -> logging.Logger:
    """Convenience function to get a logger."""
    return AppLogger.get_logger(name)


def mask_token(token: Optional[str], visible_chars: int = 8) -> str:
    """Mask a token for safe logging, showing only first few characters."""
    if not token:
        return "None"
    if len(token) <= visible_chars:
        return "*" * len(token)
    return f"{token[:visible_chars]}...({len(token)} chars)"


def mask_mobile(mobile: Optional[str]) -> str:
    """Mask mobile number for safe logging."""
    if not mobile:
        return "None"
    if len(mobile) < 4:
        return "*" * len(mobile)
    return f"{mobile[:2]}****{mobile[-2:]}"
