import json
import sys
import time

def serve():
    print("[MCP] Starting simple MCP loop...", file=sys.stderr, flush=True)
    
    while True:
        try:
            # Read a line from stdin
            line = sys.stdin.readline()
            
            # Debug log
            print(f"[MCP] Read line: {line!r}", file=sys.stderr, flush=True)
            
            if not line:
                print("[MCP] Empty line, sleeping...", file=sys.stderr, flush=True)
                time.sleep(0.1)
                continue
                
            # Parse the request
            req = json.loads(line)
            print(f"[MCP] Received request: {req}", file=sys.stderr, flush=True)
            
            method = req.get("method")
            params = req.get("params", {})
            req_id = req.get("id")
            
            # Handle initialization
            if method == "initialize":
                resp = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "status": "initialized",
                        "capabilities": {
                            "methods": {
                                "list_locations": {
                                    "params": {
                                        "type": "object",
                                        "required": [],
                                        "properties": {}
                                    }
                                }
                            }
                        }
                    }
                }
            # Handle list_locations method
            elif method == "list_locations":
                # Sample response with hardcoded locations
                locations = [
                    {"id": "1", "name": "New York", "country": "USA"},
                    {"id": "2", "name": "London", "country": "UK"},
                    {"id": "3", "name": "Tokyo", "country": "Japan"},
                    {"id": "4", "name": "Paris", "country": "France"},
                    {"id": "5", "name": "Sydney", "country": "Australia"}
                ]
                resp = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": locations
                }
            else:
                # Handle unknown method
                resp = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {
                        "code": -32601,
                        "message": f"Method '{method}' not found"
                    }
                }
            
            # Send the response
            json_resp = json.dumps(resp)
            print(json_resp, flush=True)
            print(f"[MCP] Sent response: {json_resp}", file=sys.stderr, flush=True)
            
        except Exception as e:
            print(f"[MCP] Error: {e}", file=sys.stderr, flush=True)
            
            # Try to send error response
            try:
                resp = {
                    "jsonrpc": "2.0",
                    "id": req_id if 'req_id' in locals() else None,
                    "error": {
                        "code": -32000,
                        "message": str(e)
                    }
                }
                print(json.dumps(resp), flush=True)
            except:
                pass
            
            # Keep the loop running
            continue

if __name__ == "__main__":
    serve()