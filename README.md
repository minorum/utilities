# Utilities

A collection of PowerShell maintenance scripts for cleaning up development environments and system resources on Windows.

## Overview

This repository contains automated cleanup scripts designed to help developers reclaim disk space by removing caches, old artifacts, and unused resources. All scripts are interactive, safe to run, and provide clear feedback about what they're doing.

## 🎯 Quick Start - Interactive Menu

**NEW!** Use the interactive TUI menu powered by **Spectre.Console** for a beautiful, guided experience:

```powershell
pwsh Start-MaintenanceMenu.ps1
```

The menu allows you to:
- ✨ **Select which scripts to run** - Enable/disable entire cleanup scripts
- 🎛️ **Configure individual steps** - Toggle specific steps within each script
- 📁 **Choose directories** - Pick which project folders to scan for build artifacts
- 🚀 **Run everything at once** - Execute all selected scripts in sequence

**This is the recommended way to use these maintenance scripts!**

> **Note:** The menu uses the `PwshSpectreConsole` module, which will be automatically installed on first run if not present.

---

## Scripts

### 🧹 Development Caches Cleanup
**File:** `scripts/powershell/maintenance/cleanup-dev-caches.ps1`

Removes development-related caches that can be safely regenerated on demand.

**Cleans:**
- NuGet global packages and HTTP cache
- Build artifacts (obj/bin folders) from project directories
- Visual Studio and Rider IDE caches
- VSCode cached data
- npm cache
- Temporary files

**Features:**
- Interactive prompts before removing each category
- Progress indicators for large operations
- Size calculations to show potential space savings
- Safe to run - everything cleaned will be restored on demand

**Usage:**
```powershell
pwsh scripts/powershell/maintenance/cleanup-dev-caches.ps1
```

**Typical savings:** 5-50 GB depending on your development history

---

### 🐳 Docker Cleanup
**File:** `scripts/powershell/maintenance/cleanup-docker.ps1`

Cleans Docker resources and optimizes Rancher Desktop VHDX disk usage on WSL2.

**Capabilities:**
- Prunes Docker containers, images, and volumes
- Shrinks Rancher Desktop ext4.vhdx file
- Safely stops Rancher Desktop and WSL before disk operations
- Shows before/after disk sizes

**Features:**
- Checks if Docker is running before attempting cleanup
- Automatic WSL shutdown and verification
- Uses diskpart for VHDX compaction
- Error handling for all critical operations

**Usage:**
```powershell
pwsh scripts/powershell/maintenance/cleanup-docker.ps1
```

**Requirements:**
- Rancher Desktop (if shrinking VHDX)
- Administrator privileges

**Typical savings:** 5-100 GB from VHDX shrinking

---

### 🔧 .NET SDK Manager
**File:** `scripts/powershell/maintenance/cleanup-dotnet-sdks.ps1`

Manages installed .NET SDKs with intelligent recommendations for removal.

**Features:**
- Lists all installed .NET SDKs grouped by major version
- Identifies End-of-Life (EOL) versions (e.g., .NET 6, 7)
- Detects LTS versions
- Recommends keeping only the latest patch version per major
- Interactive removal prompts

**Usage:**
```powershell
pwsh scripts/powershell/maintenance/cleanup-dotnet-sdks.ps1
```

**What it removes:**
- EOL versions (.NET 6 ended Nov 2024, .NET 7 ended May 2024)
- Older patch versions when you have multiple for the same major version

**Typical savings:** 1-5 GB

---

### 🗄️ SQL Server Cleanup
**File:** `scripts/powershell/maintenance/cleanup-sql-server.ps1`

Cleans SQL Server backups, logs, and optimizes database transaction logs.

**Capabilities:**
- Removes old backup files (.bak) older than 30 days
- Cleans trace files, dumps, and error logs
- Shrinks bloated transaction log files
- Shows detailed size information before/after operations
- Auto-detects SQL Server instances

**Features:**
- Interactive confirmation before each operation
- Identifies databases with excessive free space in log files
- Calculates optimal target sizes for log shrinking
- Supports multiple SQL Server versions and instances
- Detailed progress reporting

**Usage:**
```powershell
pwsh scripts/powershell/maintenance/cleanup-sql-server.ps1
```

**Requirements:**
- SQL Server installed and running
- Administrator privileges
- sqlcmd utility (for transaction log operations)

**Typical savings:** 1-50 GB depending on backup retention and log sizes

---

## 🎮 Using the Interactive Menu

### Features

The `Start-MaintenanceMenu.ps1` script provides a beautiful, modern TUI (Text User Interface) powered by **Spectre.Console** for managing all maintenance scripts from one place:

**Why Spectre.Console?**
- 🎨 Modern, colorful interface with rich formatting
- 📦 Well-maintained open-source library
- ⚡ Built-in multi-select menus and prompts
- 🔧 Much easier to maintain (413 lines vs 972 lines of custom code)
- 🚀 Auto-installs on first run

#### Main Menu
- View all available scripts with enable/disable status
- Toggle scripts on/off
- Configure individual script steps
- Run all selected scripts in sequence

#### Script Configuration
Each script can be configured with granular control:

**Development Caches Cleanup:**
- Toggle individual cache types (NuGet, Build Artifacts, IDE, VSCode, Node.js, Temp)
- Add/remove project directories for build artifact scanning
- Configure which folders to search for obj/bin folders

**Docker Cleanup:**
- Enable/disable Docker system prune
- Enable/disable VHDX shrinking

**.NET SDK Manager:**
- Toggle SDK listing
- Enable/disable EOL version removal
- Enable/disable older patch version removal

**SQL Server Cleanup:**
- Runs the full script (due to complexity)
- Option to skip if not needed

### Menu Navigation

The menu uses **arrow keys** and **interactive selections** (Spectre.Console):

**Main Menu:**
- Use ↑/↓ arrow keys to navigate
- Press Enter to select:
  - **Select Scripts to Run** - Multi-select which scripts to enable
  - **Configure Script Steps** - Detailed step configuration
  - **Run Selected Scripts** - Execute with confirmation
  - **Exit** - Quit the menu

**Multi-Select Menus:**
- Use ↑/↓ to navigate items
- **Space** to toggle selection (✓/✗)
- **Enter** to confirm

**Script Configuration:**
- Toggle individual steps on/off
- Enable/disable all steps at once
- Manage project directories (DevCaches only)
- Interactive table showing directory status

### Directory Management

When configuring project directories for build artifacts, the menu displays a **formatted table** showing:
- **Status** - ✓ Exists or ✗ Not Found
- **Path** - Full directory path

**Actions:**
1. **Add Directory** - Enter custom paths to scan
2. **Remove Directory** - Select from list to remove

The interactive table makes it easy to see which directories are valid at a glance.

### Example Workflow

1. **Start the menu:**
   ```powershell
   pwsh Start-MaintenanceMenu.ps1
   ```

2. **Select which scripts to run:**
   - Navigate to "Select Scripts to Run"
   - Use Space to toggle scripts (✓/✗)
   - Press Enter to confirm

3. **Configure script steps (optional):**
   - Navigate to "Configure Script Steps"
   - Choose a script to configure
   - Select "Toggle Individual Steps"
   - Use Space to toggle specific steps on/off
   - For DevCaches, manage project directories via the table interface

4. **Run everything:**
   - Navigate to "Run Selected Scripts"
   - Review the summary of what will run
   - Confirm to start execution
   - Watch as each script runs with your configuration

5. **Review results:**
   - Each script shows space freed
   - Final completion message

### Tips

- **Modern UI:** Spectre.Console provides a beautiful, professional interface
- **Easy Navigation:** Arrow keys and Space bar make it intuitive
- **Save Time:** Configure once, then run all scripts together
- **Customize:** Only run the steps you need
- **Safe:** Each script still asks for confirmation before removing files
- **Maintainable:** The menu script is now 57% smaller thanks to Spectre.Console
- **Visual:** Rich formatting, tables, and color-coded status indicators

---

## Prerequisites

### Required
- **Windows** 10/11 or Windows Server
- **PowerShell** 7+ (pwsh)
- **Administrator privileges** - All scripts require elevation

### For Interactive Menu
- **PwshSpectreConsole** module - Auto-installs on first run of `Start-MaintenanceMenu.ps1`
- Or manually install: `Install-Module -Name PwshSpectreConsole -Scope CurrentUser`

### Optional (per script)
- **Docker/Rancher Desktop** - for cleanup-docker.ps1
- **.NET SDK** - for cleanup-dotnet-sdks.ps1
- **SQL Server** - for cleanup-sql-server.ps1
- **winget** - used by cleanup-dotnet-sdks.ps1 for SDK removal

## Installation

1. Clone this repository:
```bash
git clone https://github.com/minorum/utilities.git
cd utilities
```

2. Ensure you have PowerShell 7+:
```powershell
pwsh --version
```

If not installed, get it from: https://github.com/PowerShell/PowerShell

## Usage

All scripts are designed to run interactively with confirmations before destructive operations.

### Option 1: Interactive Menu (Recommended)

```powershell
# Navigate to repository
cd utilities

# Run the interactive menu
pwsh Start-MaintenanceMenu.ps1
```

This provides a guided interface to select scripts, configure steps, and run everything from one place. See the [Using the Interactive Menu](#-using-the-interactive-menu) section for details.

### Option 2: Run Individual Scripts

```powershell
# Navigate to repository
cd utilities

# Run any script directly
pwsh scripts/powershell/maintenance/<script-name>.ps1
```

### Best Practices

1. **Review what will be removed** - Scripts show size and details before removal
2. **Run one at a time** - Some scripts may require system restarts
3. **Close applications** - Close Visual Studio, Docker Desktop, etc. before running
4. **Run regularly** - Monthly execution can prevent excessive buildup

### Safety Notes

All scripts are designed with safety in mind:
- ✅ Interactive confirmations before destructive operations
- ✅ Detailed logging of what's being removed
- ✅ Only remove regenerable caches and old artifacts
- ✅ Error handling prevents partial cleanup states
- ✅ Size calculations help you make informed decisions

**Nothing removed by these scripts is irreplaceable** - all caches, packages, and build artifacts will be regenerated when needed.

## Examples

### Quick Cleanup Routine

**Using the Interactive Menu (Easiest):**

```powershell
# Run the menu, select all scripts, and execute
pwsh Start-MaintenanceMenu.ps1

# Follow the prompts:
# 1. Press 'R' to run all scripts
# 2. Or press 'C' to configure specific steps first
# 3. Confirm when ready
```

**Running Scripts Individually:**

```powershell
# 1. Clean development caches (usually the biggest)
pwsh scripts/powershell/maintenance/cleanup-dev-caches.ps1

# 2. Clean Docker (if you use it)
pwsh scripts/powershell/maintenance/cleanup-docker.ps1

# 3. Remove old .NET SDKs
pwsh scripts/powershell/maintenance/cleanup-dotnet-sdks.ps1

# 4. Clean SQL Server (if you use it)
pwsh scripts/powershell/maintenance/cleanup-sql-server.ps1
```

Expected total savings: **10-200 GB** depending on your development history.

## Configuration

Scripts use sensible defaults, but you can modify behavior by editing the script files:

| Script | Configurable Options | Default |
|--------|---------------------|---------|
| cleanup-dev-caches.ps1 | Project directories to scan | C:\projekty, %USERPROFILE%\source\repos, %USERPROFILE%\Projects |
| cleanup-docker.ps1 | VHDX path | %LOCALAPPDATA%\rancher-desktop\distro-data\ext4.vhdx |
| cleanup-sql-server.ps1 | Age threshold for old files | 30 days |
| cleanup-sql-server.ps1 | Target log size | 100 MB or 120% of used space |

## Troubleshooting

### "Access Denied" Errors
**Solution:** Ensure you're running PowerShell as Administrator

### Script Won't Run
**Solution:** You may need to adjust execution policy:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Docker Cleanup Fails
**Solution:** Ensure Docker Desktop or Rancher Desktop is fully stopped before running

### SQL Server Script Can't Find sqlcmd
**Solution:** Install [SQL Server Command Line Utilities](https://learn.microsoft.com/en-us/sql/tools/sqlcmd-utility)

### VHDX Shrink Doesn't Reduce Size
**Solution:** The VHDX may already be optimally sized, or you need to run Docker cleanup first

## Contributing

Contributions are welcome! When adding new cleanup scripts:

1. Follow the naming convention: `cleanup-<target>.ps1`
2. Include interactive confirmations for destructive operations
3. Provide clear user feedback with color-coded messages
4. Use `try/catch` blocks for error handling
5. Test in a safe environment first
6. Update this README with documentation

See [AGENTS.md](AGENTS.md) for detailed development guidelines.

## Script Design Principles

- **Idempotent** - Safe to run multiple times
- **Interactive** - Ask before removing anything significant
- **Informative** - Show sizes and details before/after
- **Safe** - Only remove regenerable artifacts
- **No Dependencies** - Use built-in PowerShell cmdlets when possible

## Project Structure

```
utilities/
├── README.md                                    # This file
├── AGENTS.md                                    # Development guidelines for AI agents
├── Start-MaintenanceMenu.ps1                   # Interactive TUI menu (main entrypoint)
└── scripts/
    └── powershell/
        └── maintenance/
            ├── cleanup-dev-caches.ps1          # Development caches cleanup
            ├── cleanup-docker.ps1              # Docker and VHDX cleanup
            ├── cleanup-dotnet-sdks.ps1         # .NET SDK management
            └── cleanup-sql-server.ps1          # SQL Server cleanup
```

## Requirements Summary

| Script | Requires Admin | External Tools | Approx. Execution Time |
|--------|---------------|----------------|----------------------|
| cleanup-dev-caches.ps1 | ✅ Yes | None | 2-10 minutes |
| cleanup-docker.ps1 | ✅ Yes | Docker/Rancher, diskpart | 3-15 minutes |
| cleanup-dotnet-sdks.ps1 | ✅ Yes | winget, dotnet CLI | 1-5 minutes |
| cleanup-sql-server.ps1 | ✅ Yes | sqlcmd (optional) | 1-10 minutes |

## License

This project is open source and available for personal and commercial use.

## Support

For issues or questions:
- Open an issue on GitHub
- Check existing scripts for examples
- Review [AGENTS.md](AGENTS.md) for development conventions

---

**Tip:** Use `Start-MaintenanceMenu.ps1` as your one-stop solution for all maintenance tasks! You can also add it to Task Scheduler for automatic monthly cleanups.
