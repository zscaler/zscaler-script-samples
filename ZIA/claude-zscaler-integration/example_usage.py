# example_usage.py
# This script demonstrates how to use the Zscaler ZIA server with Claude Desktop

import subprocess
import sys
import time
import json

# Path to the zscaler_server.py file
SERVER_PATH = "./zscaler_server.py"

def start_server():
    """Start the Zscaler ZIA server as a subprocess."""
    print("Starting Zscaler ZIA server...")
    return subprocess.Popen([sys.executable, SERVER_PATH], 
                            stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            text=True)

def main():
    """Main function to demonstrate using the Zscaler ZIA server."""
    # Start the server
    server_process = start_server()
    
    # Wait a moment for the server to initialize
    time.sleep(1)
    
    print("\n=== Zscaler ZIA Server Example Usage ===\n")
    print("This server can be used with Claude Desktop to interact with Zscaler Internet Access.")
    print("Here are some example prompts you can use with Claude Desktop:\n")
    
    examples = [
        "Using the Zscaler tool, list all admin users. Here are my credentials: username='admin@example.com', password='your_password', api_key='your_api_key'.",
        
        "Using the Zscaler tool, get information about the URL category with ID 'GAMES'. Here are my credentials: username='admin@example.com', password='your_password', api_key='your_api_key'.",
        
        "Using the Zscaler tool, create a new location with the following details: {\"name\": \"New York Office\", \"country\": \"US\", \"timezone\": \"America/New_York\"}. Here are my credentials: username='admin@example.com', password='your_password', api_key='your_api_key'.",
        
        "Using the Zscaler tool, what resources and operations are available?"
    ]
    
    for i, example in enumerate(examples, 1):
        print(f"Example {i}:")
        print(f"  {example}\n")
    
    print("Note: When using with Claude Desktop, you'll need to:")
    print("1. Start this server in a terminal window")
    print("2. In Claude Desktop, go to Settings > Advanced > Tools")
    print("3. Add this server as a new tool with the appropriate configuration")
    print("4. Replace the example credentials with your actual Zscaler ZIA credentials")
    
    print("\nPress Ctrl+C to stop the server...")
    
    try:
        # Keep the server running until interrupted
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nStopping server...")
    finally:
        # Clean up
        server_process.terminate()
        server_process.wait()
        print("Server stopped.")

if __name__ == "__main__":
    main()