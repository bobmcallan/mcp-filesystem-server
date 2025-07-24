# MCP Filesystem Server - Binary Distribution

This directory contains the compiled MCP Filesystem Server and associated configuration files.

## Contents

- `mcp-filesystem-server.exe` - Main server executable
- `config.json` - Server configuration file
- `test.ps1` - Test suite script
- `run.ps1` - Convenience runner script
- `README.md` - This file

## Quick Start

### Test the Server
```powershell
./test.ps1
```

### Run the Server
```powershell
# Run with default settings (current directory access)
./run.ps1

# Run with specific directories
./run.ps1 -AllowedDirectories @("C:\dev", "C:\projects")

# Run with verbose logging
./run.ps1 -LogLevel debug -Verbose

# Show help
./run.ps1 -Help
```

### Manual Execution
```powershell
# Basic usage
./mcp-filesystem-server.exe .

# Multiple directories
./mcp-filesystem-server.exe "C:\dev" "C:\projects"
```

## Configuration

The `config.json` file contains server settings:

- **server**: Basic server information
- **security**: Security settings including allowed directories and file size limits
- **logging**: Logging configuration
- **mcp**: MCP protocol capabilities

## Integration with Warp

To use this server with Warp terminal, add the following to your Warp MCP configuration:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "C:\\path\\to\\this\\bin\\mcp-filesystem-server.exe",
      "args": ["."],
      "env": {},
      "description": "Secure filesystem operations via MCP"
    }
  }
}
```

## Available Tools

The server provides the following MCP tools:

- `read_file` - Read file contents
- `read_multiple_files` - Read multiple files at once
- `write_file` - Write/create files
- `copy_file` - Copy files/directories
- `move_file` - Move/rename files/directories
- `delete_file` - Delete files/directories
- `modify_file` - Find and replace in files
- `list_directory` - List directory contents
- `create_directory` - Create directories
- `tree` - Get directory tree structure
- `search_files` - Search for files by name
- `search_within_files` - Search within file contents
- `get_file_info` - Get file metadata
- `list_allowed_directories` - List accessible directories

## Security Features

- Path validation to prevent directory traversal
- Configurable allowed directories
- File size limits
- Symlink handling controls
- MIME type detection
