#!/usr/bin/env node

/**
 * MCP Bridge for Nachna Workshop API
 * Bridges Claude Desktop to the FastAPI MCP server
 */

const http = require('http');
const https = require('https');

// Configuration
const API_BASE_URL = process.env.NACHNA_SERVER_URL || 'http://localhost:8000';

// JSON-RPC protocol helpers
function createSuccessResponse(id, result) {
    return JSON.stringify({
        jsonrpc: "2.0",
        id: id,
        result: result
    });
}

function createErrorResponse(id, code, message) {
    return JSON.stringify({
        jsonrpc: "2.0",
        id: id,
        error: {
            code: code,
            message: message
        }
    });
}

// API helper function
function makeApiCall(url, method = 'GET', data = null) {
    return new Promise((resolve, reject) => {
        const protocol = url.startsWith('https:') ? https : http;
        const options = {
            method: method,
            headers: {
                'Content-Type': 'application/json'
            }
        };

        if (data) {
            const postData = JSON.stringify(data);
            options.headers['Content-Length'] = Buffer.byteLength(postData);
        }

        const req = protocol.request(url, options, (res) => {
            let responseData = '';
            res.on('data', (chunk) => {
                responseData += chunk;
            });
            res.on('end', () => {
                try {
                    const result = JSON.parse(responseData);
                    resolve(result);
                } catch (error) {
                    reject(new Error(`Parse error: ${error.message}`));
                }
            });
        });

        req.on('error', (error) => {
            reject(error);
        });

        if (data) {
            req.write(JSON.stringify(data));
        }
        req.end();
    });
}

// Handle MCP protocol messages
async function handleMessage(message) {
    try {
        switch (message.method) {
            case 'initialize':
                return createSuccessResponse(message.id, {
                    protocolVersion: "2024-11-05",
                    capabilities: {
                        tools: {
                            listChanged: false
                        },
                        resources: {
                            subscribe: false,
                            listChanged: false
                        }
                    },
                    serverInfo: {
                        name: "nachna-workshops",
                        version: "1.0.0"
                    }
                });

            case 'tools/list':
                try {
                    const toolsData = await makeApiCall(`${API_BASE_URL}/mcp/tools`);
                    const tools = toolsData.tools.map(tool => ({
                        name: tool.name,
                        description: tool.description,
                        inputSchema: tool.input_schema
                    }));

                    return createSuccessResponse(message.id, {
                        tools: tools
                    });
                } catch (error) {
                    return createErrorResponse(message.id, -32603, `Failed to list tools: ${error.message}`);
                }

            case 'tools/call':
                try {
                    const { name, arguments: args = {} } = message.params;
                    const callData = {
                        tool_name: name,
                        arguments: args
                    };

                    const result = await makeApiCall(`${API_BASE_URL}/mcp/call`, 'POST', callData);
                    
                    if (result.error) {
                        return createErrorResponse(message.id, -32603, result.error);
                    }

                    // Format the response for Claude
                    const formattedOutput = typeof result.output === 'object' 
                        ? JSON.stringify(result.output, null, 2)
                        : String(result.output || 'No output');

                    return createSuccessResponse(message.id, {
                        content: [{
                            type: "text",
                            text: formattedOutput
                        }]
                    });
                } catch (error) {
                    return createErrorResponse(message.id, -32603, `Tool call failed: ${error.message}`);
                }

            case 'resources/list':
                return createSuccessResponse(message.id, {
                    resources: [
                        {
                            uri: "workshops://all",
                            name: "All Workshops",
                            description: "Complete list of dance workshops"
                        },
                        {
                            uri: "artists://all", 
                            name: "All Artists",
                            description: "Complete list of dance artists"
                        },
                        {
                            uri: "studios://all",
                            name: "All Studios", 
                            description: "Complete list of dance studios"
                        }
                    ]
                });

            case 'resources/read':
                try {
                    const { uri } = message.params;
                    const [resourceType] = uri.split('://');
                    
                    const resourceData = await makeApiCall(`${API_BASE_URL}/mcp/resources/${resourceType}`);
                    
                    return createSuccessResponse(message.id, {
                        contents: [{
                            uri: uri,
                            mimeType: "application/json",
                            text: JSON.stringify(resourceData.data, null, 2)
                        }]
                    });
                } catch (error) {
                    return createErrorResponse(message.id, -32603, `Resource read failed: ${error.message}`);
                }

            case 'notifications/initialized':
                // Acknowledge initialization
                return;

            default:
                return createErrorResponse(message.id, -32601, `Method not found: ${message.method}`);
        }
    } catch (error) {
        return createErrorResponse(message.id, -32603, `Internal error: ${error.message}`);
    }
}

// Main server setup
process.stdin.setEncoding('utf8');
process.stdout.setEncoding('utf8');

let buffer = '';

process.stdin.on('data', async (chunk) => {
    buffer += chunk;
    
    // Process complete messages (separated by newlines)
    let lines = buffer.split('\n');
    buffer = lines.pop(); // Keep incomplete line in buffer
    
    for (let line of lines) {
        if (line.trim()) {
            try {
                const message = JSON.parse(line);
                const response = await handleMessage(message);
                if (response) {
                    process.stdout.write(response + '\n');
                }
            } catch (error) {
                const errorResponse = createErrorResponse(null, -32700, `Parse error: ${error.message}`);
                process.stdout.write(errorResponse + '\n');
            }
        }
    }
});

process.stdin.on('end', () => {
    process.exit(0);
});

// Handle process signals
process.on('SIGINT', () => {
    process.exit(0);
});

process.on('SIGTERM', () => {
    process.exit(0);
});

// Startup message
console.error(`Nachna Workshop MCP Bridge started. Connecting to ${API_BASE_URL}`);
console.error('Bridge ready to handle MCP requests from Claude Desktop'); 