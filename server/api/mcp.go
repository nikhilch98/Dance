package api

import (
	"encoding/json"
	"nachna/core"
	"nachna/database"
	"nachna/service/mcp"
	"nachna/utils"
	"net/http"
	"strings"
)

func GetMCPService() (*mcp.MCPServiceImpl, *core.NachnaException) {
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return nil, err
	}
	mcpService := mcp.MCPServiceImpl{}.GetInstance(databaseImpl)
	return mcpService, nil
}

// JSONRPC handles JSON-RPC 2.0 requests for MCP
func JSONRPC(r *http.Request) (any, *core.NachnaException) {
	if r.Method != http.MethodPost {
		return nil, &core.NachnaException{
			StatusCode:   405,
			ErrorMessage: "Method not allowed",
		}
	}

	mcpService, err := GetMCPService()
	if err != nil {
		return nil, err
	}

	var request mcp.JSONRPCRequest
	if jsonErr := json.NewDecoder(r.Body).Decode(&request); jsonErr != nil {
		return &mcp.JSONRPCResponse{
			JSONRpc: "2.0",
			Error: &mcp.RPCError{
				Code:    -32700,
				Message: "Parse error",
			},
			ID: nil,
		}, nil
	}
	defer r.Body.Close()

	response := mcpService.ProcessJSONRPC(&request)
	return response, nil
}

// ServerInfo returns server information
func ServerInfo(r *http.Request) (any, *core.NachnaException) {
	return map[string]interface{}{
		"name":        "Nachna Dance Server",
		"version":     "1.0.0",
		"description": "MCP server for Nachna dance workshop platform",
		"capabilities": map[string]interface{}{
			"tools":     true,
			"resources": true,
		},
		"endpoints": map[string]interface{}{
			"jsonrpc":   "/api/mcp",
			"tools":     "/api/mcp/tools",
			"call":      "/api/mcp/call",
			"resources": "/api/mcp/resources",
		},
	}, nil
}

// ListTools returns available MCP tools
func ListTools(r *http.Request) (any, *core.NachnaException) {
	mcpService, err := GetMCPService()
	if err != nil {
		return nil, err
	}

	tools := mcpService.ProcessJSONRPC(&mcp.JSONRPCRequest{
		JSONRpc: "2.0",
		Method:  "list_tools",
		ID:      1,
	})

	if tools.Error != nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: tools.Error.Message,
		}
	}

	return tools.Result, nil
}

// CallTool executes an MCP tool
func CallTool(r *http.Request) (any, *core.NachnaException) {
	if r.Method != http.MethodPost {
		return nil, &core.NachnaException{
			StatusCode:   405,
			ErrorMessage: "Method not allowed",
		}
	}

	mcpService, err := GetMCPService()
	if err != nil {
		return nil, err
	}

	var toolCall struct {
		Name      string                 `json:"name"`
		Arguments map[string]interface{} `json:"arguments"`
	}

	if jsonErr := json.NewDecoder(r.Body).Decode(&toolCall); jsonErr != nil {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON request body",
		}
	}
	defer r.Body.Close()

	// Convert to JSON-RPC format
	paramsData, _ := json.Marshal(toolCall)
	request := &mcp.JSONRPCRequest{
		JSONRpc: "2.0",
		Method:  "call_tool",
		Params:  paramsData,
		ID:      1,
	}

	response := mcpService.ProcessJSONRPC(request)
	if response.Error != nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: response.Error.Message,
		}
	}

	return response.Result, nil
}

// ListResources returns available MCP resources
func ListResources(r *http.Request) (any, *core.NachnaException) {
	mcpService, err := GetMCPService()
	if err != nil {
		return nil, err
	}

	resources := mcpService.ProcessJSONRPC(&mcp.JSONRPCRequest{
		JSONRpc: "2.0",
		Method:  "list_resources",
		ID:      1,
	})

	if resources.Error != nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: resources.Error.Message,
		}
	}

	return resources.Result, nil
}

// ReadResource reads a specific MCP resource
func ReadResource(r *http.Request) (any, *core.NachnaException) {
	// Extract resource type from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 4 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Resource type is required",
		}
	}

	resourceType := pathParts[len(pathParts)-1]

	mcpService, err := GetMCPService()
	if err != nil {
		return nil, err
	}

	// Convert to JSON-RPC format
	paramsData, _ := json.Marshal(map[string]string{"uri": resourceType})
	request := &mcp.JSONRPCRequest{
		JSONRpc: "2.0",
		Method:  "read_resource",
		Params:  paramsData,
		ID:      1,
	}

	response := mcpService.ProcessJSONRPC(request)
	if response.Error != nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: response.Error.Message,
		}
	}

	return response.Result, nil
}

// HealthCheck returns MCP service health status
func MCPHealthCheck(r *http.Request) (any, *core.NachnaException) {
	mcpService, err := GetMCPService()
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   503,
			ErrorMessage: "MCP service unavailable",
		}
	}

	// Test basic functionality
	response := mcpService.ProcessJSONRPC(&mcp.JSONRPCRequest{
		JSONRpc: "2.0",
		Method:  "initialize",
		ID:      "health_check",
	})

	if response.Error != nil {
		return nil, &core.NachnaException{
			StatusCode:   503,
			ErrorMessage: "MCP service unhealthy",
		}
	}

	return map[string]interface{}{
		"status":    "healthy",
		"service":   "MCP",
		"timestamp": response,
	}, nil
}

func init() {
	// MCP APIs
	Router.HandleFunc(utils.MakeHandler("/mcp", JSONRPC)).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/mcp/server-info", ServerInfo)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/mcp/tools", ListTools)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/mcp/call", CallTool)).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/mcp/resources", ListResources)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/mcp/resources/{resource_type}", ReadResource)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/mcp/health", MCPHealthCheck)).Methods(http.MethodGet)
}
