<#
.SYNOPSIS
    Securely wipes all externally connected storage devices on Windows.

.DESCRIPTION
    This script:
    - Detects all removable, non-system disks (USB, SD, etc.)
    - Asks for confirmation before wiping each one
    - Removes all partitions
    - Clears the partition table using Clear-Disk
    - Leaves the drive completely uninitialized

.NOTES
    - Requires administrator privileges
    - Use at your own risk — all data will be lost

.USAGE
    1. Run PowerShell as Administrator
    2. Execute: .\wipe_external_windows.ps1
#>

# Ensure the script is running as Administrator
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrator")) {
    Write-Error "This script must be run as Administrator."
    Exit 1
}

Write-Host "`n=== Secure wipe of all external drives (Windows) ===`n"

# Get all removable disks that are not system drives
$drives = Get-Disk | Where-Object { $_.BusType -ne 'RAID' -and $_.IsSystem -eq $false -and $_.IsBoot -eq $false -and $_.BusType -ne 'Unknown' -and $_.IsReadOnly -eq $false }

If ($drives.Count -eq 0) {
    Write-Host "No external writable drives detected. Exiting."
    Exit 0
}

# Confirm and wipe each drive
foreach ($disk in $drives) {
    Write-Host "`n>>> Detected external disk: Number $($disk.Number) - Size: $($disk.Size / 1GB) GB - Bus: $($disk.BusType)"

    $confirmation = Read-Host "Type YES to WIPE Disk $($disk.Number)"
    If ($confirmation -ne "YES") {
        Write-Host "Skipping disk $($disk.Number)."
        Continue
    }

    # Remove all partitions
    Write-Host "  Removing partitions..."
    $partitions = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue
    foreach ($part in $partitions) {
        try {
            Remove-Partition -DiskNumber $disk.Number -PartitionNumber $part.PartitionNumber -Confirm:$false -ErrorAction Stop
        } catch {
            Write-Warning "  Failed to remove partition $($part.PartitionNumber) on disk $($disk.Number)"
        }
    }

    # Clear partition table
    Write-Host "  Clearing disk $($disk.Number)..."
    try {
        Clear-Disk -Number $disk.Number -RemoveData -Confirm:$false
        Write-Host ">>> Wipe complete for disk $($disk.Number)"
    } catch {
        Write-Warning "  Failed to clear disk $($disk.Number)"
    }
}

Write-Host "`n=== All confirmed external drives wiped ==="
