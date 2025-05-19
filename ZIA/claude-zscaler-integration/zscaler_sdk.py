# zscaler_sdk.py
"""
Simple wrapper for the Zscaler SDK to be used with the MCP tool.
This provides functions to be used by the zscaler_server.py file.
"""

from typing import Dict, Any, Optional, Tuple, List
from zscaler.oneapi_client import LegacyZIAClient

class ZIAHelper:
    """Helper class for Zscaler Internet Access API operations."""
    
    @staticmethod
    def create_client(username: str, password: str, api_key: str, cloud: str = "zscloud") -> LegacyZIAClient:
        """Create and return an authenticated ZIA client."""
        config = {
            "username": username,
            "password": password,
            "api_key": api_key,
            "cloud": cloud,
            "logging": {"enabled": True, "verbose": False},
        }
        
        return LegacyZIAClient(config)
    
    @staticmethod
    def list_admin_users(client: LegacyZIAClient) -> Tuple[List[Dict[str, Any]], Any, Any]:
        """List all admin users in ZIA."""
        with client as zia:
            # Try different method names that might exist
            method_options = [
                'list_users', 'get_users', 'list_admin_users', 'get_admin_users', 
                'list', 'get_all', 'list_all'
            ]
            
            for method_name in method_options:
                if hasattr(zia.zia.admin_users, method_name):
                    method = getattr(zia.zia.admin_users, method_name)
                    return method()
            
            # If no method is found, raise an error
            raise AttributeError("No list method found for admin_users")
    
    @staticmethod
    def get_admin_user(client: LegacyZIAClient, user_id: str) -> Tuple[Dict[str, Any], Any, Any]:
        """Get a specific admin user by ID."""
        with client as zia:
            # Try different method names that might exist
            method_options = [
                'get_user', 'get', 'get_admin_user', 'get_by_id'
            ]
            
            for method_name in method_options:
                if hasattr(zia.zia.admin_users, method_name):
                    method = getattr(zia.zia.admin_users, method_name)
                    return method(user_id)
            
            # If no method is found, raise an error
            raise AttributeError("No get method found for admin_users")
    
    @staticmethod
    def create_admin_user(client: LegacyZIAClient, user_data: Dict[str, Any]) -> Tuple[Dict[str, Any], Any, Any]:
        """Create a new admin user."""
        with client as zia:
            # Try different method names that might exist
            method_options = [
                'add_user', 'add', 'create', 'create_user', 'create_admin_user'
            ]
            
            for method_name in method_options:
                if hasattr(zia.zia.admin_users, method_name):
                    method = getattr(zia.zia.admin_users, method_name)
                    return method(user_data)
            
            # If no method is found, raise an error
            raise AttributeError("No create method found for admin_users")
    
    @staticmethod
    def update_admin_user(client: LegacyZIAClient, user_id: str, user_data: Dict[str, Any]) -> Tuple[Dict[str, Any], Any, Any]:
        """Update an existing admin user."""
        with client as zia:
            # Try different method names that might exist
            method_options = [
                'update_user', 'update', 'edit', 'update_admin_user'
            ]
            
            for method_name in method_options:
                if hasattr(zia.zia.admin_users, method_name):
                    method = getattr(zia.zia.admin_users, method_name)
                    return method(user_id, user_data)
            
            # If no method is found, raise an error
            raise AttributeError("No update method found for admin_users")
    
    @staticmethod
    def delete_admin_user(client: LegacyZIAClient, user_id: str) -> Tuple[Any, Any, Any]:
        """Delete an admin user."""
        with client as zia:
            # Try different method names that might exist
            method_options = [
                'delete_user', 'delete', 'remove', 'delete_admin_user'
            ]
            
            for method_name in method_options:
                if hasattr(zia.zia.admin_users, method_name):
                    method = getattr(zia.zia.admin_users, method_name)
                    return method(user_id)
            
            # If no method is found, raise an error
            raise AttributeError("No delete method found for admin_users")
    
    @staticmethod
    def get_available_resources(client: LegacyZIAClient) -> List[str]:
        """Get a list of available resource types in the ZIA client."""
        with client as zia:
            return [attr for attr in dir(zia.zia) if not attr.startswith('_')]
    
    @staticmethod
    def get_available_methods(client: LegacyZIAClient, resource_type: str) -> List[str]:
        """Get a list of available methods for a specific resource type."""
        with client as zia:
            if hasattr(zia.zia, resource_type):
                resource = getattr(zia.zia, resource_type)
                return [method for method in dir(resource) if not method.startswith('_')]
            else:
                return []
    
    @staticmethod
    def execute_method(client: LegacyZIAClient, resource_type: str, method_name: str, *args, **kwargs) -> Tuple[Any, Any, Any]:
        """Execute a specific method on a resource type with the given arguments."""
        with client as zia:
            if hasattr(zia.zia, resource_type):
                resource = getattr(zia.zia, resource_type)
                if hasattr(resource, method_name):
                    method = getattr(resource, method_name)
                    return method(*args, **kwargs)
                else:
                    raise AttributeError(f"Method {method_name} not found for resource {resource_type}")
            else:
                raise AttributeError(f"Resource {resource_type} not found")

# Example usage
if __name__ == "__main__":
    # This is just for demonstration, not actual use
    client = ZIAHelper.create_client(
        username="example@example.com",
        password="password",
        api_key="api_key"
    )
    
    # Example: List admin users
    users, response, error = ZIAHelper.list_admin_users(client)
    
    # Example: Get available resources
    resources = ZIAHelper.get_available_resources(client)
    
    # Example: Get available methods for admin_users
    methods = ZIAHelper.get_available_methods(client, "admin_users")
    
    # Example: Execute a specific method
    result, response, error = ZIAHelper.execute_method(
        client, "admin_users", "list", page=1, page_size=20
    )