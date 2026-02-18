Gateway Launcher
===============

A modern Windows application for managing OpenClaw Gateway.

REQUIREMENTS
------------
- Windows 10/11
- PowerShell 5.1 or later
- Node.js and pnpm (for running the gateway)

USAGE
-----
1. Run GatewayLauncher.exe
2. Configure the project path in config/settings.json
3. Use the buttons to start/stop the gateway

The application will:
- Look for config/settings.json in the same directory
- Use default settings if no config is found
- Run in system tray when minimized

FILES
-----
- GatewayLauncher.exe  - Main application
- modules/             - Application modules (required)
- config/              - Configuration files (optional)

SUPPORT
-------
For issues and feature requests, contact the development team.
