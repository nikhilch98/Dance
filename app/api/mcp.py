"""MCP (Model Context Protocol) API routes - OpenAI Compatible."""

from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse
import uuid
import json
import traceback

from app.models.mcp import (
    McpListToolsResponse,
    McpCallResponse,
    McpResourceResponse,
)
from app.services.mcp_service import McpWorkshopService

router = APIRouter()


def create_jsonrpc_response(id: Any, result: Any = None, error: Any = None):
    """Create a JSON-RPC 2.0 response"""
    response = {
        "jsonrpc": "2.0",
        "id": id
    }
    if error:
        response["error"] = error
    else:
        response["result"] = result
    return response


def create_jsonrpc_error(id: Any, code: int, message: str, data: Any = None):
    """Create a JSON-RPC 2.0 error response"""
    error = {
        "code": code,
        "message": message
    }
    if data:
        error["data"] = data
    return create_jsonrpc_response(id, error=error)


@router.post("/")
async def mcp_jsonrpc_endpoint(request: Request):
    """Main MCP JSON-RPC endpoint for OpenAI integration"""
    # Set CORS headers for OpenAI
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "*"
    }
    
    try:
        body = await request.json()
        body_str = json.dumps(body)
    except Exception as e:
        return JSONResponse(
            create_jsonrpc_error(None, -32700, f"Parse error: {str(e)}"),
            status_code=400,
            headers=headers
        )
    
    # Handle JSON-RPC request
    try:
        method = body.get("method")
        params = body.get("params", {})
        request_id = body.get("id")
        
        if method == "initialize":
            result = {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {
                        "listChanged": False
                    },
                    "resources": {
                        "subscribe": False,
                        "listChanged": False
                    }
                },
                "serverInfo": {
                    "name": "nachna-workshops",
                    "version": "1.0.0"
                }
            }
            return JSONResponse(
                create_jsonrpc_response(request_id, result),
                headers=headers
            )
        
        elif method == "tools/list":
            tools_data = McpWorkshopService.list_tools()
            tools = []
            for tool in tools_data.tools:
                tools.append({
                    "name": tool.name,
                    "description": tool.description,
                    "inputSchema": tool.input_schema
                })
            
            result = {"tools": tools}
            return JSONResponse(
                create_jsonrpc_response(request_id, result),
                headers=headers
            )
        
        elif method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments", {})
            
            if not tool_name:
                return JSONResponse(
                    create_jsonrpc_error(request_id, -32602, "Missing tool name"),
                    status_code=400,
                    headers=headers
                )
            
            call_id = str(uuid.uuid4())
            call_result = McpWorkshopService.call_tool(tool_name, arguments, call_id)

            if call_result.error:
                print(f"MCP Tool Error - Tool: {tool_name}, Error: {call_result.error}, Request: {body_str}")
                return JSONResponse(
                    create_jsonrpc_error(request_id, -32603, call_result.error),
                    status_code=500,
                    headers=headers
                )
            
            # Format response for OpenAI
            result = {
                "content": [
                    {
                        "type": "text",
                        "text": json.dumps(call_result.output, indent=2) if call_result.output else "No output"
                    }
                ]
            }
            return JSONResponse(
                create_jsonrpc_response(request_id, result),
                headers=headers
            )
        
        elif method == "resources/list":
            result = {
                "resources": [
                    {
                        "uri": "workshops://all",
                        "name": "All Workshops",
                        "description": "Complete list of dance workshops"
                    },
                    {
                        "uri": "artists://all",
                        "name": "All Artists", 
                        "description": "Complete list of dance artists"
                    },
                    {
                        "uri": "studios://all",
                        "name": "All Studios",
                        "description": "Complete list of dance studios"
                    }
                ]
            }
            return JSONResponse(
                create_jsonrpc_response(request_id, result),
                headers=headers
            )
        
        elif method == "resources/read":
            uri = params.get("uri")
            if not uri:
                return JSONResponse(
                    create_jsonrpc_error(request_id, -32602, "Missing resource URI"),
                    status_code=400,
                    headers=headers
                )
            
            resource_type = uri.split("://")[0]
            resource_data = McpWorkshopService.get_resource(resource_type)
            
            result = {
                "contents": [
                    {
                        "uri": uri,
                        "mimeType": "application/json",
                        "text": json.dumps(resource_data.data, indent=2)
                    }
                ]
            }
            return JSONResponse(
                create_jsonrpc_response(request_id, result),
                headers=headers
            )
        
        elif method == "notifications/initialized":
            # Acknowledge initialization notification
            return JSONResponse(
                create_jsonrpc_response(request_id, {}),
                headers=headers
            )
        
        else:
            return JSONResponse(
                create_jsonrpc_error(request_id, -32601, f"Method not found: {method}"),
                status_code=404,
                headers=headers
            )
            
    except Exception as e:
        print(f"MCP JSON-RPC Error: {str(e)}")
        print(f"Request body: {body_str if 'body_str' in locals() else 'Could not parse'}")
        print(f"Traceback: {traceback.format_exc()}")
        return JSONResponse(
            create_jsonrpc_error(request_id if 'request_id' in locals() else None, -32603, f"Internal error: {str(e)}"),
            status_code=500,
            headers=headers
        )


@router.get("/server-info")
async def get_mcp_server_info():
    """Get MCP server information and capabilities (REST endpoint for testing)"""
    return {
        "server_label": McpWorkshopService.SERVER_LABEL,
        "server_version": McpWorkshopService.SERVER_VERSION,
        "protocol_version": "2024-11-05",
        "supported_operations": ["initialize", "tools/list", "tools/call", "resources/list", "resources/read"],
        "available_resources": ["workshops", "artists", "studios"],
        "capabilities": {
            "tools": True,
            "resources": True,
            "prompts": False,
            "logging": False
        },
        "tools_count": len(McpWorkshopService.get_available_tools()),
        "openai_compatible": True,
        "jsonrpc_endpoint": "/mcp/"
    }


@router.get("/tools", response_model=McpListToolsResponse)
async def list_mcp_tools():
    """List all available MCP tools (REST endpoint for testing)"""
    try:
        return McpWorkshopService.list_tools()
    except Exception as e:
        print(f"Error listing MCP tools: {e}")
        print(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail="Failed to list MCP tools")


@router.post("/call", response_model=McpCallResponse)
async def call_mcp_tool(
    tool_name: str,
    arguments: dict = {},
    call_id: Optional[str] = None
):
    """Execute an MCP tool call (REST endpoint for testing)"""
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
    """Get a resource with MCP metadata (REST endpoint for testing)"""
    try:
        return McpWorkshopService.get_resource(resource_type, resource_id)
    except Exception as e:
        print(f"Error getting MCP resource: {e}")
        print(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Failed to get resource: {str(e)}")


@router.get("/health")
async def mcp_health_check():
    """Health check for MCP server"""
    try:
        # Test that we can get tools
        tools = McpWorkshopService.get_available_tools()
        return {
            "status": "healthy",
            "server_label": McpWorkshopService.SERVER_LABEL,
            "server_version": McpWorkshopService.SERVER_VERSION,
            "tools_available": len(tools),
            "protocol_version": "2024-11-05",
            "openai_compatible": True
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"MCP server unhealthy: {str(e)}") 