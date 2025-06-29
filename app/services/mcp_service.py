"""MCP (Model Context Protocol) service for workshop-related operations."""

import time
import uuid
from typing import List, Dict, Any, Optional
from app.models.mcp import (
    McpToolDefinition,
    McpListToolsResponse,
    McpCallResponse,
    McpResourceResponse,
)
from app.database.workshops import DatabaseOperations


class McpWorkshopService:
    """Service for handling MCP protocol operations for workshops."""
    
    SERVER_LABEL = "nachna-workshops"
    SERVER_VERSION = "1.0.0"
    
    @classmethod
    def get_available_tools(cls) -> List[McpToolDefinition]:
        """Define available MCP tools for workshop operations."""
        return [
            McpToolDefinition(
                name="get_workshops_categorized",
                description="Retrieve all workshops categorized by current week and future periods",
                input_schema={
                    "type": "object",
                    "properties": {
                        "studio_id": {
                            "type": "string",
                            "description": "Optional studio ID to filter workshops by specific studio"
                        }
                    },
                    "additionalProperties": False
                }
            ),
            McpToolDefinition(
                name="get_workshops_by_artist",
                description="Retrieve workshops for a specific artist",
                input_schema={
                    "type": "object",
                    "properties": {
                        "artist_id": {
                            "type": "string",
                            "description": "The unique identifier of the artist"
                        }
                    },
                    "required": ["artist_id"],
                    "additionalProperties": False
                }
            ),
            McpToolDefinition(
                name="get_artists",
                description="Retrieve all artists with optional filtering",
                input_schema={
                    "type": "object",
                    "properties": {
                        "has_workshops": {
                            "type": "boolean",
                            "description": "Filter artists who have workshops"
                        }
                    },
                    "additionalProperties": False
                }
            ),
            McpToolDefinition(
                name="get_studios",
                description="Retrieve all dance studios",
                input_schema={
                    "type": "object",
                    "properties": {},
                    "additionalProperties": False
                }
            ),
        ]
    
    @classmethod
    def list_tools(cls) -> McpListToolsResponse:
        """List all available MCP tools."""
        return McpListToolsResponse(
            id=str(uuid.uuid4()),
            server_label=cls.SERVER_LABEL,
            tools=cls.get_available_tools(),
            type="mcp_list_tools"
        )
    
    @classmethod
    def call_tool(cls, tool_name: str, arguments: Dict[str, Any], call_id: str) -> McpCallResponse:
        """Execute an MCP tool call."""
        try:
            if tool_name == "get_workshops_categorized":
                studio_id = arguments.get("studio_id")
                result = DatabaseOperations.get_all_workshops_categorized(studio_id)
                return McpCallResponse(
                    id=call_id,
                    name=tool_name,
                    server_label=cls.SERVER_LABEL,
                    type="mcp_call",
                    output=result.model_dump()
                )
            
            elif tool_name == "get_workshops_by_artist":
                artist_id = arguments.get("artist_id")
                if not artist_id:
                    raise ValueError("artist_id is required")
                result = DatabaseOperations.get_workshops_by_artist(artist_id)
                return McpCallResponse(
                    id=call_id,
                    name=tool_name,
                    server_label=cls.SERVER_LABEL,
                    type="mcp_call",
                    output=[workshop.model_dump() for workshop in result]
                )
            
            elif tool_name == "get_artists":
                has_workshops = arguments.get("has_workshops")
                result = DatabaseOperations.get_artists(has_workshops=has_workshops)
                return McpCallResponse(
                    id=call_id,
                    name=tool_name,
                    server_label=cls.SERVER_LABEL,
                    type="mcp_call",
                    output=[artist.model_dump() for artist in result]
                )
            
            elif tool_name == "get_studios":
                result = DatabaseOperations.get_studios()
                return McpCallResponse(
                    id=call_id,
                    name=tool_name,
                    server_label=cls.SERVER_LABEL,
                    type="mcp_call",
                    output=[studio.model_dump() for studio in result]
                )
            
            else:
                return McpCallResponse(
                    id=call_id,
                    name=tool_name,
                    server_label=cls.SERVER_LABEL,
                    type="mcp_call",
                    error=f"Unknown tool: {tool_name}"
                )
                
        except Exception as e:
            return McpCallResponse(
                id=call_id,
                name=tool_name,
                server_label=cls.SERVER_LABEL,
                type="mcp_call",
                error=str(e)
            )
    
    @classmethod
    def get_resource(cls, resource_type: str, resource_id: Optional[str] = None) -> McpResourceResponse:
        """Get a resource with MCP metadata."""
        try:
            if resource_type == "workshops":
                if resource_id:
                    # Get workshops for specific studio
                    data = DatabaseOperations.get_all_workshops_categorized(resource_id)
                else:
                    # Get all workshops
                    data = DatabaseOperations.get_all_workshops_categorized()
                
                return McpResourceResponse(
                    resource_type=resource_type,
                    resource_id=resource_id or "all",
                    data=data.model_dump(),
                    metadata={
                        "server_label": cls.SERVER_LABEL,
                        "server_version": cls.SERVER_VERSION,
                        "total_this_week": len(data.this_week),
                        "total_future": len(data.post_this_week),
                        "cache_ttl": 3600,
                        "last_updated": time.time(),
                    },
                    timestamp=time.time()
                )
            
            elif resource_type == "artists":
                data = DatabaseOperations.get_artists()
                return McpResourceResponse(
                    resource_type=resource_type,
                    resource_id=resource_id or "all",
                    data=[artist.model_dump() for artist in data],
                    metadata={
                        "server_label": cls.SERVER_LABEL,
                        "server_version": cls.SERVER_VERSION,
                        "total_count": len(data),
                        "cache_ttl": 3600,
                        "last_updated": time.time(),
                    },
                    timestamp=time.time()
                )
            
            elif resource_type == "studios":
                data = DatabaseOperations.get_studios()
                return McpResourceResponse(
                    resource_type=resource_type,
                    resource_id=resource_id or "all",
                    data=[studio.model_dump() for studio in data],
                    metadata={
                        "server_label": cls.SERVER_LABEL,
                        "server_version": cls.SERVER_VERSION,
                        "total_count": len(data),
                        "cache_ttl": 3600,
                        "last_updated": time.time(),
                    },
                    timestamp=time.time()
                )
            
            else:
                raise ValueError(f"Unknown resource type: {resource_type}")
                
        except Exception as e:
            return McpResourceResponse(
                resource_type=resource_type,
                resource_id=resource_id or "unknown",
                data=None,
                metadata={
                    "server_label": cls.SERVER_LABEL,
                    "error": str(e),
                    "timestamp": time.time(),
                },
                timestamp=time.time()
            ) 