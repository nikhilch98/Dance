"""MCP (Model Context Protocol) API routes."""

from typing import Optional
from fastapi import APIRouter, HTTPException, Body
import uuid

from app.models.mcp import (
    McpListToolsResponse,
    McpCallResponse,
    McpResourceResponse,
)
from app.services.mcp_service import McpWorkshopService

router = APIRouter()


@router.get("/server-info")
async def get_mcp_server_info():
    """Get MCP server information and capabilities."""
    return {
        "server_label": McpWorkshopService.SERVER_LABEL,
        "server_version": McpWorkshopService.SERVER_VERSION,
        "protocol_version": "1.0",
        "supported_operations": ["list_tools", "call_tool", "get_resource"],
        "available_resources": ["workshops", "artists", "studios"],
        "capabilities": {
            "tools": True,
            "resources": True,
            "prompts": False,
            "logging": False
        },
        "tools_count": len(McpWorkshopService.get_available_tools())
    }


@router.get("/tools", response_model=McpListToolsResponse)
async def list_mcp_tools():
    """List all available MCP tools for workshop operations."""
    try:
        return McpWorkshopService.list_tools()
    except Exception as e:
        print(f"Error listing MCP tools: {e}")
        raise HTTPException(status_code=500, detail="Failed to list MCP tools")


@router.post("/call", response_model=McpCallResponse)
async def call_mcp_tool(
    tool_name: str,
    arguments: dict = Body(default={}),
    call_id: Optional[str] = None
):
    """Execute an MCP tool call."""
    try:
        if not call_id:
            call_id = str(uuid.uuid4())
        
        return McpWorkshopService.call_tool(tool_name, arguments, call_id)
    except Exception as e:
        print(f"Error in MCP tool call: {e}")
        return McpCallResponse(
            id=call_id or str(uuid.uuid4()),
            name=tool_name,
            server_label=McpWorkshopService.SERVER_LABEL,
            type="mcp_call",
            error=str(e)
        )


@router.get("/resources/{resource_type}", response_model=McpResourceResponse)
async def get_mcp_resource(resource_type: str, resource_id: Optional[str] = None):
    """Get a resource with MCP metadata."""
    try:
        return McpWorkshopService.get_resource(resource_type, resource_id)
    except Exception as e:
        print(f"Error getting MCP resource: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get resource: {str(e)}") 