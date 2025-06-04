# Zscaler ZIA Tool for Claude Desktop

This tool allows Claude Desktop to interact with Zscaler Internet Access (ZIA) APIs, enabling you to perform various operations such as managing admin users, URL categories, locations, and other ZIA resources.

## Prerequisites

1. Python 3.8 or higher
2. Claude Desktop application
3. Zscaler Internet Access (ZIA) account with API access
4. Required Python packages:
   - `zscaler-sdk-python` - Install with `pip install zscaler-sdk`
   - `fastmcp` - Install with `pip install fastmcp`

## File Structure

The tool consists of the following files:

- `zscaler_server.py` - Main MCP server implementation that handles requests from Claude Desktop
- `zscaler_sdk.py` - Helper module with utility functions for the Zscaler SDK
- `example_usage.py` - Example script for testing the server standalone

## Installation

1. Create a directory for the tool (e.g., `~/Claude/tools/zia_api_tool/`)
2. Copy the provided Python files to this directory
3. Make the server script executable:
   ```bash
   chmod +x ~/Claude/tools/zia_api_tool/zscaler_server.py
   ```

## Configuring the MCP Server in Claude Desktop

Claude Desktop uses the Machine-Oriented Communication Protocol (MCP) to communicate with external tools. Follow these steps to configure the Zscaler ZIA Tool:

### macOS Configuration

1. Locate the Claude Desktop configuration directory:
   ```
   ~/Library/Application Support/Claude/
   ```

2. Create or edit the `claude_desktop_config.json` file in this directory:
   ```bash
   touch ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

3. Add the following content to the file, replacing paths with your actual file locations:
   ```json
   {
     "mcpServers": {
       "zscaler-zia-tool": {
         "command": "/usr/local/bin/python3",
         "args": ["/full/path/to/zscaler_server.py"],
         "working_directory": "/full/path/to/directory/containing/zscaler_server"
       }
     }
   }
   ```

4. Replace the placeholder paths:
   - `/usr/local/bin/python3` should be the path to your Python executable (verify with `which python3`)
   - `/full/path/to/zscaler_server.py` should be the full path to the script (e.g., `~/Claude/tools/zia_api_tool/zscaler_server.py` expanded to absolute path)
   - `/full/path/to/directory/containing/zscaler_server` should be the directory containing the script (e.g., `~/Claude/tools/zia_api_tool` expanded to absolute path)

### Windows Configuration

1. Locate the Claude Desktop configuration directory:
   ```
   %APPDATA%\Claude\
   ```

2. Create or edit the `claude_desktop_config.json` file in this directory with the following content:
   ```json
   {
     "mcpServers": {
       "zscaler-zia-tool": {
         "command": "C:\\Path\\To\\Python\\python.exe",
         "args": ["C:\\Path\\To\\zscaler_server.py"],
         "working_directory": "C:\\Path\\To\\Directory\\"
       }
     }
   }
   ```

3. Replace the placeholder paths with your actual paths.

## Verifying the Configuration

1. After adding the configuration file, restart Claude Desktop.
2. The Zscaler ZIA Tool should now appear in the list of available tools in Claude Desktop.
3. To verify it's working, you can ask Claude: "Using the Zscaler ZIA Tool, what resources and operations are available?"

## Using the Tool

You can use the Zscaler ZIA Tool by asking Claude to perform operations with it. Here are some example prompts:

1. **List Available Resources**:
   ```
   Using the Zscaler ZIA Tool, what resources and operations are available?
   ```

2. **List Admin Users**:
   ```
   Using the Zscaler ZIA Tool, list all admin users. Here are my credentials: username='your_email', password='your_password', api_key='your_api_key'.
   ```

3. **Get URL Category Information**:
   ```
   Using the Zscaler ZIA Tool, get information about the URL category with ID 'GAMES'. Here are my credentials: username='your_email', password='your_password', api_key='your_api_key'.
   ```

4. **Create a New Location**:
   ```
   Using the Zscaler ZIA Tool, create a new location with the following details: {"name": "New York Office", "country": "US", "timezone": "America/New_York"}. Here are my credentials: username='your_email', password='your_password', api_key='your_api_key'.
   ```

## Troubleshooting

If the tool doesn't appear in Claude Desktop after configuration:

1. Check that the JSON configuration file is correctly formatted
2. Verify that the paths in the configuration file are correct and absolute
3. Make sure the required Python packages are installed
4. Check that the Python script has execution permissions
5. Restart Claude Desktop after making changes
6. Check Claude Desktop logs:
   - macOS: `~/Library/Logs/Claude/`
   - Windows: `%APPDATA%\Claude\logs\`

## Security Notes

- Your Zscaler credentials are passed to the tool only when you make a request
- For better security, consider implementing a secure credential storage system rather than typing credentials in each request
- Never share your API keys or passwords with unauthorized users

## Available Resources

The Zscaler ZIA Tool provides access to the following resources:

1. Admin Users and Roles Management
2. URL Categories Configuration
3. Locations Management
4. DLP (Data Loss Prevention) Configuration
5. Firewall Rules Management
6. User Management
7. URL Filtering Policies
8. And more...

Each resource supports standard operations like listing, getting specific items, creating new items, updating existing items, and deleting items.
