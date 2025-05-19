# zscaler_server.py
from mcp.server.fastmcp import FastMCP
import sys
from typing import Optional, Dict, Any, List
import json

# Import the Zscaler SDK components
from zscaler.oneapi_client import LegacyZIAClient

# Create an MCP server
mcp = FastMCP("Zscaler ZIA Service")

def create_zia_client(username: str, password: str, api_key: str, cloud: str = "zscloud"):
    """Create and authenticate a ZIA client using legacy authentication."""
    print(f"[MCP] Creating ZIA client for {username} on {cloud}", file=sys.stderr, flush=True)
    
    # Create the configuration dictionary for legacy authentication
    config = {
        "username": username,
        "password": password,
        "api_key": api_key,
        "cloud": cloud,
        "logging": {"enabled": True, "verbose": False},
    }
    
    # Create the ZIA client with legacy authentication
    zia_client = LegacyZIAClient(config)
    
    # Return the authenticated client
    return zia_client

@mcp.tool()
def zia_request(query: str, username: str, password: str, api_key: str, 
                method: Optional[str] = None, 
                resource_type: Optional[str] = None,
                resource_id: Optional[str] = None,
                data: Optional[Dict[str, Any]] = None,
                params: Optional[Dict[str, Any]] = None,
                cloud: str = "zscloud",
                page_size: int = 100,
                page: int = 1) -> Dict[str, Any]:
    """
    Make a request to ZIA API using the Zscaler SDK based on natural language query or specific parameters
    
    Args:
        query: Natural language description of the request (e.g. "List all admin users")
        username: ZIA admin username
        password: ZIA admin password
        api_key: ZIA API key
        method: HTTP method (GET, POST, PUT, DELETE) - optional, will be inferred if not provided
        resource_type: Resource type (admin_users, url_categories, etc.) - optional, will be inferred if not provided
        resource_id: Resource ID for specific resource operations (optional)
        data: Request body for POST/PUT (optional) 
        params: Query parameters (optional)
        cloud: ZIA cloud (default: zscloud)
        page_size: Number of items per page for paginated results (default: 100)
        page: Page number for paginated results (default: 1)
    
    Returns:
        JSON response from the API
    """
    print(f"[MCP] zia_request tool called with query: {query}", file=sys.stderr, flush=True)
    
    # Create a ZIA client
    client = create_zia_client(username, password, api_key, cloud)
    
    # Initialize default response
    response = {"error": "Unable to process request"}
    result = None
    error = None
    
    try:
        # Process the natural language query to determine operation and resource type
        query_lower = query.lower()
        
        # Infer resource_type if not provided
        if not resource_type:
            if "admin user" in query_lower or "admin_users" in query_lower:
                resource_type = "admin_users"
            elif "url categor" in query_lower or "url_categories" in query_lower:
                resource_type = "url_categories"
            elif "location" in query_lower:
                resource_type = "locations"
            elif "rule" in query_lower and "firewall" in query_lower:
                resource_type = "firewall_filtering_rules"
            elif "url filter" in query_lower:
                resource_type = "url_filtering_rules"
            elif "dlp" in query_lower:
                resource_type = "dlp_dictionaries"
            # Add more resource types as needed
        
        if not resource_type:
            return {"error": "Unable to determine resource type from query. Please specify the resource_type parameter."}
        
        print(f"[MCP] Using resource type: {resource_type}", file=sys.stderr, flush=True)
        
        # Use the client in a context manager to ensure proper authentication and cleanup
        with client as zia_client:
            # Get the resource module
            if hasattr(zia_client.zia, resource_type):
                resource_module = getattr(zia_client.zia, resource_type)
            else:
                return {"error": f"Resource type '{resource_type}' not found in the Zscaler API client"}
            
            # List available methods for this resource
            available_methods = [m for m in dir(resource_module) if not m.startswith('_')]
            print(f"[MCP] Available methods for {resource_type}: {available_methods}", file=sys.stderr, flush=True)
            
            # Infer the method if not provided
            if not method:
                if "list" in query_lower or "get all" in query_lower or "show all" in query_lower:
                    method = "LIST"
                elif "create" in query_lower or "add" in query_lower:
                    method = "ADD"
                elif "update" in query_lower or "edit" in query_lower or "modify" in query_lower:
                    method = "UPDATE"
                elif "delete" in query_lower or "remove" in query_lower:
                    method = "DELETE"
                elif "get" in query_lower or "retrieve" in query_lower or "find" in query_lower:
                    method = "GET"
                else:
                    method = "LIST"  # Default to LIST if we can't determine
            
            print(f"[MCP] Using method: {method}", file=sys.stderr, flush=True)
            
            # Map the method to available methods in the SDK
            if method.upper() == "LIST":
                method_options = [
                    'list_users', 'get_users', f'list_{resource_type}', f'get_{resource_type}', 
                    'list', 'get_all', 'list_all', 'get', 'list_locations', 'get_locations'
                ]
                
                # Find the first method that exists
                method_name = None
                for option in method_options:
                    if option in available_methods:
                        method_name = option
                        break
                
                if method_name:
                    method_func = getattr(resource_module, method_name)
                    print(f"[MCP] Calling {method_name} method", file=sys.stderr, flush=True)
                    
                    # Handle pagination parameters if supported
                    if params:
                        result, response_obj, error = method_func(params=params)
                    else:
                        result, response_obj, error = method_func()
                else:
                    error = f"No list method found for {resource_type}. Available methods: {available_methods}"
            
            elif method.upper() == "GET" and resource_id:
                method_options = [
                    'get_user', 'get', f'get_{resource_type.rstrip("s")}', 'get_by_id'
                ]
                
                method_name = None
                for option in method_options:
                    if option in available_methods:
                        method_name = option
                        break
                
                if method_name:
                    method_func = getattr(resource_module, method_name)
                    print(f"[MCP] Calling {method_name} method with ID: {resource_id}", file=sys.stderr, flush=True)
                    
                    # Call the method with the resource ID
                    if params:
                        result, response_obj, error = method_func(resource_id, params=params)
                    else:
                        result, response_obj, error = method_func(resource_id)
                else:
                    error = f"No get method found for {resource_type}. Available methods: {available_methods}"
            
            elif method.upper() == "ADD" or method.upper() == "CREATE":
                method_options = [
                    'add_user', 'add', 'create', f'add_{resource_type.rstrip("s")}', 
                    f'create_{resource_type.rstrip("s")}'
                ]
                
                method_name = None
                for option in method_options:
                    if option in available_methods:
                        method_name = option
                        break
                
                if method_name and data:
                    method_func = getattr(resource_module, method_name)
                    print(f"[MCP] Calling {method_name} method with data", file=sys.stderr, flush=True)
                    
                    # Call the method with the data
                    result, response_obj, error = method_func(data)
                else:
                    if not method_name:
                        error = f"No add method found for {resource_type}. Available methods: {available_methods}"
                    else:
                        error = "Data is required for add operations"
            
            elif method.upper() == "UPDATE" or method.upper() == "PUT":
                method_options = [
                    'update_user', 'update', 'edit', f'update_{resource_type.rstrip("s")}'
                ]
                
                method_name = None
                for option in method_options:
                    if option in available_methods:
                        method_name = option
                        break
                
                if method_name and resource_id and data:
                    method_func = getattr(resource_module, method_name)
                    print(f"[MCP] Calling {method_name} method with ID: {resource_id} and data", file=sys.stderr, flush=True)
                    
                    # Call the method with the resource ID and data
                    result, response_obj, error = method_func(resource_id, data)
                else:
                    if not method_name:
                        error = f"No update method found for {resource_type}. Available methods: {available_methods}"
                    else:
                        error = "Resource ID and data are required for update operations"
            
            elif method.upper() == "DELETE":
                method_options = [
                    'delete_user', 'delete', 'remove', f'delete_{resource_type.rstrip("s")}'
                ]
                
                method_name = None
                for option in method_options:
                    if option in available_methods:
                        method_name = option
                        break
                
                if method_name and resource_id:
                    method_func = getattr(resource_module, method_name)
                    print(f"[MCP] Calling {method_name} method with ID: {resource_id}", file=sys.stderr, flush=True)
                    
                    # Call the method with the resource ID
                    result, response_obj, error = method_func(resource_id)
                else:
                    if not method_name:
                        error = f"No delete method found for {resource_type}. Available methods: {available_methods}"
                    else:
                        error = "Resource ID is required for delete operations"
            
            else:
                error = f"Unsupported method: {method}"
            
            # Prepare the response
            if error:
                response = {"error": str(error)}
            else:
                response = {
                    "result": result,
                    "status": "success",
                    "method_used": method_name,
                    "resource_type": resource_type
                }
    
    except Exception as e:
        print(f"[MCP] Error: {str(e)}", file=sys.stderr, flush=True)
        response = {"error": str(e)}
    
    # Return the response
    return response

@mcp.tool()
def get_zia_resources() -> Dict[str, Any]:
    """
    Get information about available ZIA SDK resources and methods
    
    Returns:
        Dictionary of available resources and their capabilities
    """
    print("[MCP] get_zia_resources tool called", file=sys.stderr, flush=True)
    
    # Create a sample client to inspect available resources
    try:
        # Create a temporary client to inspect the structure
        # Note: This doesn't actually authenticate, it just helps us explore the structure
        temp_config = {
            "username": "temp",
            "password": "temp",
            "api_key": "temp",
            "cloud": "zscloud",
            "logging": {"enabled": False, "verbose": False},
        }
        
        client = LegacyZIAClient(temp_config)
        
        # Get available resources by inspecting the zia attribute
        available_resources = {}
        
        # Common ZIA resources and their descriptions
        resource_descriptions = {
            "admin_users": "ZIA administrator users and roles",
            "url_categories": "URL categories for content filtering",
            "locations": "Physical or logical locations",
            "firewall_filtering_rules": "Firewall filtering rules",
            "url_filtering_rules": "URL filtering rules",
            "dlp_dictionaries": "Data Loss Prevention dictionaries",
            "sandbox_settings": "Sandbox analysis settings",
            "security_policy_settings": "Security policy settings",
            "user_authentication_settings": "User authentication settings",
            "traffic_forwarding": "Traffic forwarding settings and GRE tunnels",
            "ssl_inspection": "SSL inspection settings and certificates",
            "device_groups": "Device groups for mobile and IoT devices",
            "cloud_firewall_settings": "Cloud firewall settings",
            "dlp_engines": "Data Loss Prevention engines",
            "dlp_notification_templates": "Data Loss Prevention notification templates",
            "dlp_web_rules": "Data Loss Prevention web rules"
        }
        
        # Check if each resource exists in the client and add example queries
        zia_attrs = [attr for attr in dir(client.zia) if not attr.startswith('_')]
        
        for attr in zia_attrs:
            if attr in resource_descriptions:
                available_resources[attr] = {
                    "description": resource_descriptions[attr],
                    "operations": ["LIST", "GET", "ADD", "UPDATE", "DELETE"],
                    "example_queries": [
                        f"List all {attr.replace('_', ' ')}",
                        f"Get {attr.replace('_', ' ')} with ID 12345",
                        f"Create a new {attr.replace('_', ' ').rstrip('s')}",
                        f"Update {attr.replace('_', ' ').rstrip('s')} with ID 12345",
                        f"Delete {attr.replace('_', ' ').rstrip('s')} with ID 12345"
                    ]
                }
            else:
                # For resources not in our predefined list, add with a generic description
                available_resources[attr] = {
                    "description": f"ZIA {attr.replace('_', ' ')}",
                    "operations": ["LIST", "GET", "ADD", "UPDATE", "DELETE"],
                    "example_queries": [
                        f"List all {attr.replace('_', ' ')}",
                        f"Get {attr.replace('_', ' ')} with ID 12345",
                        f"Create a new {attr.replace('_', ' ').rstrip('s')}",
                        f"Update {attr.replace('_', ' ').rstrip('s')} with ID 12345",
                        f"Delete {attr.replace('_', ' ').rstrip('s')} with ID 12345"
                    ]
                }
    except Exception as e:
        print(f"[MCP] Error inspecting ZIA resources: {str(e)}", file=sys.stderr, flush=True)
        # Fallback to a static resource list
        available_resources = {
            "admin_users": {
                "description": "ZIA administrator users",
                "operations": ["LIST", "GET", "ADD", "UPDATE", "DELETE"],
                "example_queries": [
                    "List all admin users",
                    "Get admin user with ID 12345",
                    "Create a new admin user",
                    "Update admin user with ID 12345",
                    "Delete admin user with ID 12345"
                ]
            },
            "url_categories": {
                "description": "URL categories for content filtering",
                "operations": ["LIST", "GET", "ADD", "UPDATE", "DELETE"],
                "example_queries": [
                    "List all URL categories",
                    "Get URL category with ID games",
                    "Create a new URL category",
                    "Update URL category with ID custom_category",
                    "Delete URL category with ID custom_category"
                ]
            },
            "locations": {
                "description": "Physical or logical locations",
                "operations": ["LIST", "GET", "ADD", "UPDATE", "DELETE"],
                "example_queries": [
                    "List all locations",
                    "Get location with ID 12345",
                    "Create a new location",
                    "Update location with ID 12345",
                    "Delete location with ID 12345"
                ]
            },
            "firewall_filtering_rules": {
                "description": "Firewall filtering rules",
                "operations": ["LIST", "GET", "ADD", "UPDATE", "DELETE"],
                "example_queries": [
                    "List all firewall rules",
                    "Get firewall rule with ID 12345",
                    "Create a new firewall rule",
                    "Update firewall rule with ID 12345",
                    "Delete firewall rule with ID 12345"
                ]
            },
            "url_filtering_rules": {
                "description": "URL filtering rules",
                "operations": ["LIST", "GET", "ADD", "UPDATE", "DELETE"],
                "example_queries": [
                    "List all URL filtering rules",
                    "Get URL filtering rule with ID 12345",
                    "Create a new URL filtering rule",
                    "Update URL filtering rule with ID 12345",
                    "Delete URL filtering rule with ID 12345"
                ]
            }
        }
    
    return {
        "available_resources": available_resources,
        "authentication": {
            "type": "legacy",
            "required_parameters": ["username", "password", "api_key"],
            "optional_parameters": ["cloud"]
        },
        "pagination": {
            "parameters": ["page_size", "page"]
        },
        "usage_notes": [
            "The Zscaler ZIA API uses Legacy authentication with username, password, and API key",
            "Resource operations return a tuple of (result, response, error)",
            "Method names in the SDK may vary by resource type",
            "The zia_request tool will attempt to find the appropriate method based on your query"
        ]
    }

if __name__ == "__main__":
    # Run the server using stdio transport by default
    print("[MCP] Starting Zscaler ZIA server...", file=sys.stderr, flush=True)
    mcp.run()