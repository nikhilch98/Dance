package mcp

import (
	"context"
	"encoding/json"
	"fmt"
	"nachna/database"
	"sync"
	"time"
)

type MCPServiceImpl struct {
	databaseImpl *database.MongoDBDatabaseImpl
}

var mcpServiceInstance *MCPServiceImpl
var mcpServiceLock = &sync.Mutex{}

func (MCPServiceImpl) GetInstance(databaseImpl *database.MongoDBDatabaseImpl) *MCPServiceImpl {
	if mcpServiceInstance == nil {
		mcpServiceLock.Lock()
		defer mcpServiceLock.Unlock()
		if mcpServiceInstance == nil {
			mcpServiceInstance = &MCPServiceImpl{
				databaseImpl: databaseImpl,
			}
		}
	}
	return mcpServiceInstance
}

// JSON-RPC 2.0 structures
type JSONRPCRequest struct {
	JSONRpc string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
	ID      interface{}     `json:"id"`
}

type JSONRPCResponse struct {
	JSONRpc string      `json:"jsonrpc"`
	Result  interface{} `json:"result,omitempty"`
	Error   *RPCError   `json:"error,omitempty"`
	ID      interface{} `json:"id"`
}

type RPCError struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

type ServerInfo struct {
	Name        string `json:"name"`
	Version     string `json:"version"`
	Description string `json:"description"`
}

type Tool struct {
	Name        string      `json:"name"`
	Description string      `json:"description"`
	InputSchema interface{} `json:"inputSchema"`
}

type Resource struct {
	Type        string `json:"type"`
	Name        string `json:"name"`
	Description string `json:"description"`
	MimeType    string `json:"mimeType,omitempty"`
}

// ProcessJSONRPC processes a JSON-RPC 2.0 request
func (m *MCPServiceImpl) ProcessJSONRPC(request *JSONRPCRequest) *JSONRPCResponse {
	response := &JSONRPCResponse{
		JSONRpc: "2.0",
		ID:      request.ID,
	}

	switch request.Method {
	case "initialize":
		response.Result = m.handleInitialize()
	case "list_tools":
		response.Result = m.handleListTools()
	case "call_tool":
		result, err := m.handleCallTool(request.Params)
		if err != nil {
			response.Error = &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    err.Error(),
			}
		} else {
			response.Result = result
		}
	case "list_resources":
		response.Result = m.handleListResources()
	case "read_resource":
		result, err := m.handleReadResource(request.Params)
		if err != nil {
			response.Error = &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    err.Error(),
			}
		} else {
			response.Result = result
		}
	default:
		response.Error = &RPCError{
			Code:    -32601,
			Message: "Method not found",
		}
	}

	return response
}

func (m *MCPServiceImpl) handleInitialize() interface{} {
	return map[string]interface{}{
		"protocolVersion": "2024-11-05",
		"capabilities": map[string]interface{}{
			"tools":     map[string]interface{}{},
			"resources": map[string]interface{}{},
		},
		"serverInfo": ServerInfo{
			Name:        "Nachna Dance Server",
			Version:     "1.0.0",
			Description: "MCP server for Nachna dance workshop platform",
		},
	}
}

func (m *MCPServiceImpl) handleListTools() interface{} {
	tools := []Tool{
		{
			Name:        "get_workshops",
			Description: "Get all available dance workshops",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"limit": map[string]interface{}{
						"type":        "number",
						"description": "Maximum number of workshops to return",
						"default":     50,
					},
				},
			},
		},
		{
			Name:        "get_artists",
			Description: "Get all dance artists",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"limit": map[string]interface{}{
						"type":        "number",
						"description": "Maximum number of artists to return",
						"default":     50,
					},
				},
			},
		},
		{
			Name:        "search_workshops",
			Description: "Search workshops by song or artist name",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"query": map[string]interface{}{
						"type":        "string",
						"description": "Search query for workshops",
					},
				},
				"required": []string{"query"},
			},
		},
		{
			Name:        "get_user_stats",
			Description: "Get user statistics and engagement data",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"user_id": map[string]interface{}{
						"type":        "string",
						"description": "User ID to get stats for",
					},
				},
			},
		},
		{
			Name:        "get_workshop_stats",
			Description: "Get workshop engagement statistics",
			InputSchema: map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"workshop_id": map[string]interface{}{
						"type":        "string",
						"description": "Workshop ID to get stats for",
					},
				},
				"required": []string{"workshop_id"},
			},
		},
	}

	return map[string]interface{}{
		"tools": tools,
	}
}

func (m *MCPServiceImpl) handleCallTool(params json.RawMessage) (interface{}, error) {
	var toolCall struct {
		Name      string                 `json:"name"`
		Arguments map[string]interface{} `json:"arguments"`
	}

	if err := json.Unmarshal(params, &toolCall); err != nil {
		return nil, fmt.Errorf("invalid tool call parameters: %v", err)
	}

	ctx := context.Background()

	switch toolCall.Name {
	case "get_workshops":
		return m.getWorkshops(ctx, toolCall.Arguments)
	case "get_artists":
		return m.getArtists(ctx, toolCall.Arguments)
	case "search_workshops":
		return m.searchWorkshops(ctx, toolCall.Arguments)
	case "get_user_stats":
		return m.getUserStats(ctx, toolCall.Arguments)
	case "get_workshop_stats":
		return m.getWorkshopStats(ctx, toolCall.Arguments)
	default:
		return nil, fmt.Errorf("unknown tool: %s", toolCall.Name)
	}
}

func (m *MCPServiceImpl) handleListResources() interface{} {
	resources := []Resource{
		{
			Type:        "workshops",
			Name:        "All Workshops",
			Description: "Complete list of all dance workshops",
			MimeType:    "application/json",
		},
		{
			Type:        "artists",
			Name:        "All Artists",
			Description: "Complete list of all dance artists",
			MimeType:    "application/json",
		},
		{
			Type:        "studios",
			Name:        "All Studios",
			Description: "Complete list of all dance studios",
			MimeType:    "application/json",
		},
		{
			Type:        "analytics",
			Name:        "Platform Analytics",
			Description: "Platform-wide analytics and statistics",
			MimeType:    "application/json",
		},
	}

	return map[string]interface{}{
		"resources": resources,
	}
}

func (m *MCPServiceImpl) handleReadResource(params json.RawMessage) (interface{}, error) {
	var resourceRead struct {
		URI string `json:"uri"`
	}

	if err := json.Unmarshal(params, &resourceRead); err != nil {
		return nil, fmt.Errorf("invalid resource read parameters: %v", err)
	}

	ctx := context.Background()

	switch resourceRead.URI {
	case "workshops":
		return m.getAllWorkshopsResource(ctx)
	case "artists":
		return m.getAllArtistsResource(ctx)
	case "studios":
		return m.getAllStudiosResource(ctx)
	case "analytics":
		return m.getAnalyticsResource(ctx)
	default:
		return nil, fmt.Errorf("unknown resource: %s", resourceRead.URI)
	}
}

// Tool implementations
func (m *MCPServiceImpl) getWorkshops(ctx context.Context, args map[string]interface{}) (interface{}, error) {
	workshops, err := m.databaseImpl.GetAllWorkshops(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get workshops: %v", err)
	}

	limit := 50
	if l, ok := args["limit"].(float64); ok && l > 0 {
		limit = int(l)
	}

	if len(workshops) > limit {
		workshops = workshops[:limit]
	}

	return map[string]interface{}{
		"workshops": workshops,
		"count":     len(workshops),
		"total":     len(workshops),
	}, nil
}

func (m *MCPServiceImpl) getArtists(ctx context.Context, args map[string]interface{}) (interface{}, error) {
	artists, err := m.databaseImpl.GetAllArtists(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get artists: %v", err.ErrorMessage)
	}

	limit := 50
	if l, ok := args["limit"].(float64); ok && l > 0 {
		limit = int(l)
	}

	if len(artists) > limit {
		artists = artists[:limit]
	}

	return map[string]interface{}{
		"artists": artists,
		"count":   len(artists),
		"total":   len(artists),
	}, nil
}

func (m *MCPServiceImpl) searchWorkshops(ctx context.Context, args map[string]interface{}) (interface{}, error) {
	query, ok := args["query"].(string)
	if !ok {
		return nil, fmt.Errorf("query parameter is required")
	}

	workshops, err := m.databaseImpl.SearchWorkshops(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to search workshops: %v", err)
	}

	return map[string]interface{}{
		"workshops": workshops,
		"count":     len(workshops),
		"query":     query,
	}, nil
}

func (m *MCPServiceImpl) getUserStats(ctx context.Context, args map[string]interface{}) (interface{}, error) {
	userID, ok := args["user_id"].(string)
	if !ok {
		return nil, fmt.Errorf("user_id parameter is required")
	}

	// Get user reactions
	reactions, err := m.databaseImpl.GetUserReactions(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user reactions: %v", err)
	}

	return map[string]interface{}{
		"user_id":   userID,
		"reactions": reactions,
		"timestamp": time.Now(),
	}, nil
}

func (m *MCPServiceImpl) getWorkshopStats(ctx context.Context, args map[string]interface{}) (interface{}, error) {
	workshopID, ok := args["workshop_id"].(string)
	if !ok {
		return nil, fmt.Errorf("workshop_id parameter is required")
	}

	// Get workshop reaction stats
	stats, err := m.databaseImpl.GetReactionStats(ctx, workshopID, "workshop")
	if err != nil {
		return nil, fmt.Errorf("failed to get workshop stats: %v", err)
	}

	return stats, nil
}

// Resource implementations
func (m *MCPServiceImpl) getAllWorkshopsResource(ctx context.Context) (interface{}, error) {
	workshops, err := m.databaseImpl.GetAllWorkshops(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get workshops: %v", err.ErrorMessage)
	}

	return map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"type":     "text",
				"text":     fmt.Sprintf("Total workshops: %d", len(workshops)),
				"mimeType": "text/plain",
			},
			{
				"type":     "resource",
				"resource": workshops,
				"mimeType": "application/json",
			},
		},
	}, nil
}

func (m *MCPServiceImpl) getAllArtistsResource(ctx context.Context) (interface{}, error) {
	artists, err := m.databaseImpl.GetAllArtists(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get artists: %v", err.ErrorMessage)
	}

	return map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"type":     "text",
				"text":     fmt.Sprintf("Total artists: %d", len(artists)),
				"mimeType": "text/plain",
			},
			{
				"type":     "resource",
				"resource": artists,
				"mimeType": "application/json",
			},
		},
	}, nil
}

func (m *MCPServiceImpl) getAllStudiosResource(ctx context.Context) (interface{}, error) {
	studios, err := m.databaseImpl.GetAllStudiosFromDB(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get studios: %v", err.ErrorMessage)
	}

	return map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"type":     "text",
				"text":     fmt.Sprintf("Total studios: %d", len(studios)),
				"mimeType": "text/plain",
			},
			{
				"type":     "resource",
				"resource": studios,
				"mimeType": "application/json",
			},
		},
	}, nil
}

func (m *MCPServiceImpl) getAnalyticsResource(ctx context.Context) (interface{}, error) {
	insights, err := m.databaseImpl.GetAppInsights(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get analytics: %v", err.ErrorMessage)
	}

	return map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"type":     "text",
				"text":     "Platform Analytics Dashboard",
				"mimeType": "text/plain",
			},
			{
				"type":     "resource",
				"resource": insights,
				"mimeType": "application/json",
			},
		},
	}, nil
}
