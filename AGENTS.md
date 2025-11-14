# AGENTS.md

## Project Overview

This repository contains PowerShell scripts for system and development environment maintenance. The main focus is on cleaning up caches, Docker resources, .NET SDKs, and SQL Server artifacts. All scripts are located under `scripts/powershell/maintenance/`.

## Directory Structure

- `scripts/powershell/maintenance/`: Contains all maintenance scripts. Each script targets a specific cleanup task (e.g., `cleanup-dotnet-sdks.ps1`, `cleanup-docker.ps1`).

## Agent Guidance

- **Script Naming**: Use the `cleanup-<target>.ps1` pattern for new scripts.
- **Idempotency**: Ensure scripts are safe to run multiple times without causing errors or leaving the system in an inconsistent state.
- **No External Dependencies**: Rely only on built-in PowerShell cmdlets and standard Windows tools. Avoid introducing external dependencies unless absolutely necessary.
- **Parameterization**: Accept parameters for customization, but default behavior should be safe and non-destructive.
- **Logging**: Use `Write-Host` for user-facing output. Prefer clear, actionable messages (e.g., what was deleted, skipped, or failed).
- **Error Handling**: Use `try/catch` blocks for critical operations. Log errors but do not stop the entire script unless a fatal issue occurs.

## Developer Workflows

- **Running Scripts**: Execute scripts directly in PowerShell. Example:

  ```powershell
  pwsh scripts/powershell/maintenance/cleanup-dotnet-sdks.ps1
  ```

- **Testing**: Manual testing is standard. Run scripts in a safe environment before applying to production systems.
- **Extending**: To add a new cleanup script, follow the naming and structure conventions. Place new scripts in the same directory.

## Examples

- To clean up Docker resources:

  ```powershell
  pwsh scripts/powershell/maintenance/cleanup-docker.ps1
  ```

- To clean up .NET SDKs:

  ```powershell
  pwsh scripts/powershell/maintenance/cleanup-dotnet-sdks.ps1
  ```

## Notable Files

- `README.md`: User-facing documentation with comprehensive usage instructions, examples, and troubleshooting.
- `scripts/powershell/maintenance/cleanup-dev-caches.ps1`: Removes NuGet packages, build artifacts, IDE caches, and temp files.
- `scripts/powershell/maintenance/cleanup-docker.ps1`: Cleans up Docker containers, images, volumes, and shrinks Rancher Desktop VHDX.
- `scripts/powershell/maintenance/cleanup-dotnet-sdks.ps1`: Manages and removes .NET SDKs with EOL detection.
- `scripts/powershell/maintenance/cleanup-sql-server.ps1`: Cleans SQL Server backups, logs, and shrinks transaction logs.

## Additional Notes

- No CI/CD or automated test integration is present.
- The `README.md` serves as user-facing documentation; this file (AGENTS.md) is for AI agent guidance.

---

For questions or unclear conventions, review existing scripts for examples or ask for clarification.
