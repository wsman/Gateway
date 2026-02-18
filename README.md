# Gateway Launcher

A modern Windows desktop application for managing OpenClaw Gateway services. Built with PowerShell and WinForms, packaged as a standalone Windows EXE.

## Features

- **Modern Nordic Theme** - Clean, modern UI design
- **System Tray Integration** - Minimize to system tray, background operation
- **Gateway Management** - Start/stop Gateway in foreground or background
- **Dashboard** - Real-time status monitoring
- **Port Management** - Check and clean ports
- **Log Viewing** - View Gateway logs directly in the app

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Node.js and pnpm (for running the Gateway)

## Building from Source

### Prerequisites

1. PowerShell 5.1 or later
2. Internet connection (for first-time module installation)

### Build Steps

1. Open PowerShell in the project directory:

   ```powershell
   cd D:\Users\SallyX\Desktop\Claude\Gateway
   ```

2. Run the build script:

   ```powershell
   .\build.ps1
   ```

   The script will:
   - Check for and install the PS2EXE module if needed
   - Compile `GatewayLauncher.ps1` into `GatewayLauncher.exe`
   - Copy supporting files (modules, config)
   - Output everything to the `dist\` folder
   - Test the compiled EXE

3. The compiled application will be in the `dist\` folder:

   ```
   dist\
   ├── GatewayLauncher.exe   (Main application)
   ├── modules\              (Required modules)
   ├── config\               (Configuration folder)
   └── README.txt            (Quick reference)
   ```

### Optional: Custom Icon

Place an icon file in the project root before building:
- `app.ico`
- `icon.ico`
- `GatewayLauncher.ico`

The build script will automatically use it if found.

### Skip Testing

To build without running the test:

```powershell
.\build.ps1 -NoTest
```

## Using the Application

### First Run

1. Run `GatewayLauncher.exe` from the `dist\` folder
2. If no config exists, create one:

   ```powershell
   cd dist
   .\create_config.ps1
   ```

3. Edit `config\settings.json` to set your project path:

   ```json
   {
     "ProjectPath": "D:\\path\\to\\your\\project",
     "GatewayPort": 3000,
     "ThemePreference": "Nordic",
     "AutoStart": false,
     "LogLevel": "info"
   }
   ```

### Application Controls

| Button | Description |
|--------|-------------|
| Start (Foreground) | Start Gateway in a new command window |
| Start (Background) | Start Gateway hidden in background |
| Stop | Stop the Gateway process |
| Status | Check if Gateway port is in use |
| Logs | View recent Gateway logs |
| Clean Ports | Force stop all processes on Gateway port |
| Clear | Clear the output log |

### System Tray

- **Minimize** - Click the X button to minimize to system tray
- **Show Window** - Double-click tray icon or use menu
- **Quick Start/Stop** - Right-click tray icon for menu

## Configuration

Configuration file location: `config\settings.json` (in the same folder as the EXE)

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| ProjectPath | string | "" | Path to your OpenClaw project |
| GatewayPort | number | 3000 | Port for Gateway server |
| ThemePreference | string | "Nordic" | UI theme (Nordic) |
| AutoStart | boolean | false | Auto-start Gateway on launch |
| LogLevel | string | "info" | Logging verbosity |

## Development

### Project Structure

```
Gateway\
├── build.ps1              (Build script)
├── GatewayLauncher.ps1    (Main application entry)
├── modules\
│   ├── Theme.ps1         (Nordic theme styling)
│   ├── Config.ps1        (Configuration management)
│   ├── TrayIcon.ps1      (System tray functionality)
│   └── Dashboard.ps1     (Status dashboard)
├── config\               (Configuration files)
└── dist\                 (Build output)
```

### Module Dependencies

The application uses dot-sourcing to load modules:
- `Theme.ps1` - Must be loaded first (provides styling)
- `Config.ps1` - Configuration management
- `TrayIcon.ps1` - System tray functionality
- `Dashboard.ps1` - Dashboard UI components

## Troubleshooting

### "Module not found" errors

Ensure the `modules\` folder is in the same directory as the EXE.

### Gateway won't start

1. Check the project path in settings.json
2. Verify pnpm is installed: `pnpm --version`
3. Check port availability: `netstat -ano | findstr :3000`

### Application crashes on startup

1. Check PowerShell version: `$PSVersionTable.PSVersion`
2. Run from PowerShell to see errors: `.\GatewayLauncher.ps1`
3. Check Windows Event Viewer for application errors

## License

Copyright (c) 2026 OpenClaw. All rights reserved.
