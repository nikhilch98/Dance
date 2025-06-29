"""MCP (Model Context Protocol) specific data models."""

from typing import List, Optional, Dict, Any, Literal
from pydantic import BaseModel


class McpToolDefinition(BaseModel):
    """MCP tool definition following the Model Context Protocol standard."""
    name: str
    description: str
    input_schema: Dict[str, Any]


class McpListToolsResponse(BaseModel):
    """MCP tools listing response."""
    id: str
    server_label: str
    tools: List[McpToolDefinition]
    type: Literal["mcp_list_tools"]
    error: Optional[str] = None


class McpCallRequest(BaseModel):
    """MCP tool call request."""
    id: str
    name: str
    arguments: Dict[str, Any]
    server_label: str
    type: Literal["mcp_call"]


class McpCallResponse(BaseModel):
    """MCP tool call response."""
    id: str
    name: str
    server_label: str
    type: Literal["mcp_call"]
    output: Optional[Any] = None
    error: Optional[str] = None


class McpResourceResponse(BaseModel):
    """MCP resource response with metadata."""
    resource_type: str
    resource_id: str
    data: Any
    metadata: Dict[str, Any]
    timestamp: float
    version: str = "1.0"