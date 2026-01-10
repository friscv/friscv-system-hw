param (
    [string]$Target = "project",
    [string]$ProgBin = "test/prog.bin"
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectName = "friscv-system-hw"
$ProjectDir = Join-Path $PSScriptRoot $ProjectName
$ScriptsDir = Join-Path $PSScriptRoot "scripts"
$OverlayDir = Join-Path $PSScriptRoot "overlay"

# Check for Vivado
if (-not (Get-Command "vivado" -ErrorAction SilentlyContinue)) {
    Write-Error "Vivado not found in PATH. Please add Vivado bin directory to your PATH."
}

# Helper wrapper for Vivado batch mode
function Run-Vivado {
    param([string]$Script, [string[]]$Args)
    Write-Host "Running Vivado script: $Script" -ForegroundColor Cyan
    $validScriptPath = $Script -replace "\\", "/"
    if ($Args.Count -gt 0) {
        & vivado -mode batch -nolog -nojournal -source $validScriptPath -tclargs @Args
    } else {
        & vivado -mode batch -nolog -nojournal -source $validScriptPath
    }
}

# Helper wrapper for XSDB
function Run-XSDB {
    param([string]$Script, [string[]]$Args)
    if (-not (Get-Command "xsdb" -ErrorAction SilentlyContinue)) {
        Write-Error "XSDB not found in PATH."
    }
    Write-Host "Running XSDB script: $Script" -ForegroundColor Cyan
    $validScriptPath = $Script -replace "\\", "/"
    if ($Args.Count -gt 0) {
        & xsdb $validScriptPath @Args
    } else {
        & xsdb $validScriptPath
    }
}

switch ($Target) {
    "project" {
        Write-Host "Creating Vivado project..." -ForegroundColor Green
        Run-Vivado "$ScriptsDir\create_project.tcl"
        Write-Host "Done! Project created at: $ProjectDir\$ProjectName.xpr"
    }

    "export-bd" {
        if (-not (Test-Path "$ProjectDir\$ProjectName.xpr")) {
            Write-Error "Project not found. Run '.\build.ps1 -Target project' first."
        }
        Write-Host "Exporting block designs to TCL..." -ForegroundColor Green
        Run-Vivado "$ScriptsDir\export_bd.tcl"
    }

    "bitstream" {
        if (-not (Test-Path "$ProjectDir\$ProjectName.xpr")) {
            Write-Error "Project not found. Run '.\build.ps1 -Target project' first."
        }

        Write-Host "=== CLEANING OLD BITSTREAM FILES ===" -ForegroundColor Yellow
        $DirsToRemove = @(
            "$ProjectDir\$ProjectName.runs\impl_1",
            "$ProjectDir\$ProjectName.runs\synth_1",
            "$ProjectDir\$ProjectName.runs\design_1_friscv_soc_wrapper_0_synth_1",
            "$ProjectDir\$ProjectName.runs\design_1_ps_0_synth_1",
            "$ProjectDir\$ProjectName.cache",
            "$ProjectDir\$ProjectName.gen"
        )
        foreach ($d in $DirsToRemove) {
            if (Test-Path $d) { Remove-Item $d -Recurse -Force }
        }
        
        # Clean specific IP files (simplified globbing)
        if (Test-Path "bd\design_1\ip\design_1_friscv_soc_wrapper_0") {
            Get-ChildItem "bd\design_1\ip\design_1_friscv_soc_wrapper_0\*.dcp" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
            Get-ChildItem "bd\design_1\ip\design_1_friscv_soc_wrapper_0\synth\*.v" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
        }
        
        if (Test-Path "$PSScriptRoot\$ProjectName.xsa") { Remove-Item "$PSScriptRoot\$ProjectName.xsa" }

        Write-Host "Old files cleaned."
        Write-Host "=== BUILDING NEW BITSTREAM ===" -ForegroundColor Green
        Run-Vivado "$ScriptsDir\build_bitstream.tcl"

        Write-Host "=== DEPLOYING ARTIFACTS TO $OverlayDir ===" -ForegroundColor Green
        if (-not (Test-Path $OverlayDir)) { New-Item -ItemType Directory -Path $OverlayDir | Out-Null }

        # Copy .bit file
        $BitFile = Get-ChildItem "$ProjectDir\$ProjectName.runs\impl_1" -Filter "*.bit" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($BitFile) {
            Copy-Item $BitFile.FullName -Destination "$OverlayDir\friscv.bit" -Force
            Write-Host "Copied bitstream to $OverlayDir\friscv.bit"
        } else {
            Write-Error "Bitstream generation failed. No .bit file found."
        }

        # Handle .hwh file
        $HwhFile = Get-ChildItem $ProjectDir -Filter "*.hwh" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($HwhFile) {
            Copy-Item $HwhFile.FullName -Destination "$OverlayDir\friscv.hwh" -Force
        } else {
            Write-Warning ".hwh not found directly. Attempting to extract from XSA..."
            $XsaFile = "$PSScriptRoot\$ProjectName.xsa"
            if (Test-Path $XsaFile) {
                # XSA files are ZIP archives, but need .zip extension for Expand-Archive
                $TempZip = "$XsaFile.zip"
                Copy-Item $XsaFile -Destination $TempZip -Force
                Expand-Archive -Path $TempZip -DestinationPath "$ScriptsDir\.xsa_tmp" -Force
                Remove-Item $TempZip -Force
                
                $ExtractedHwh = Get-ChildItem "$ScriptsDir\.xsa_tmp" -Filter "*.hwh" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($ExtractedHwh) {
                    Copy-Item $ExtractedHwh.FullName -Destination "$OverlayDir\friscv.hwh" -Force
                    Write-Host "Extracted HWH from XSA."
                } else {
                    Write-Error "Could not find .hwh inside XSA file."
                }
                Remove-Item "$ScriptsDir\.xsa_tmp" -Recurse -Force
            } else {
                Write-Error "Could not find .hwh or .xsa file!"
            }
        }

        # Extract ps7_init.tcl
        $XsaFile = "$PSScriptRoot\$ProjectName.xsa"
        if (Test-Path $XsaFile) {
            Write-Host "Extracting ps7_init.tcl from XSA..."
            $TempZip = "$XsaFile.zip"
            Copy-Item $XsaFile -Destination $TempZip -Force
            Expand-Archive -Path $TempZip -DestinationPath "$ScriptsDir\.ps_init_tmp" -Force
            Remove-Item $TempZip -Force
            
            $PsInit = Get-ChildItem "$ScriptsDir\.ps_init_tmp" -Filter "ps7_init.tcl" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($PsInit) {
                Copy-Item $PsInit.FullName -Destination "$ScriptsDir\ps7_init.tcl" -Force
                Write-Host "Extracted ps7_init.tcl to $ScriptsDir\"
            }
            Remove-Item "$ScriptsDir\.ps_init_tmp" -Recurse -Force
        }

        # Final cleanup
        if (Test-Path $XsaFile) { Remove-Item $XsaFile }

        Write-Host "=== BUILD COMPLETE ===" -ForegroundColor Green
    }

    "program" {
        $BitPath = "$OverlayDir\friscv.bit"
        if (-not (Test-Path $BitPath)) {
            Write-Error "Bitstream not found. Run '.\build.ps1 -Target bitstream' first."
        }
        Write-Host "=== PROGRAMMING FPGA VIA JTAG ===" -ForegroundColor Green
        $ScriptPath = ($ScriptsDir + "\program_fpga.tcl") -replace "\\", "/"
        $BitstreamArg = $BitPath -replace "\\", "/"
        Write-Host "Running Vivado script: $ScriptPath" -ForegroundColor Cyan
        vivado -mode batch -nolog -nojournal -source $ScriptPath -tclargs $BitstreamArg
        Write-Host "FPGA programmed successfully!"
    }

    "status" {
        Write-Host "=== CHECKING FPGA STATUS ===" -ForegroundColor Green
        Run-XSDB "$ScriptsDir\check_status.tcl"
    }

    "reset" {
        Write-Host "=== RESETTING FRISC-V CORE ===" -ForegroundColor Green
        Run-XSDB "$ScriptsDir\hold_reset.tcl"
    }

    "load" {
        if (-not (Test-Path $ProgBin)) {
            Write-Error "Binary file '$ProgBin' not found."
        }
        Write-Host "=== LOADING PROGRAM TO MEMORY ===" -ForegroundColor Green
        Write-Host "Binary: $ProgBin"
        $ScriptPath = ($ScriptsDir + "\load_program.tcl") -replace "\\", "/"
        $BinArg = $ProgBin -replace "\\", "/"
        Write-Host "Running XSDB script: $ScriptPath" -ForegroundColor Cyan
        & xsdb $ScriptPath $BinArg "0x0"
    }

    "run" {
        Write-Host "=== RELEASING FRISC-V CORE FROM RESET ===" -ForegroundColor Green
        Run-XSDB "$ScriptsDir\release_reset.tcl"
    }

    "open" {
        Write-Host "Opening project in GUI..."
        vivado -mode gui -nolog -nojournal "$ProjectDir\$ProjectName.xpr"
    }

    "clean" {
        Write-Host "=== CLEANING PROJECT ===" -ForegroundColor Yellow
        
        # Remove .Xil directory
        $XilDir = Join-Path $PSScriptRoot ".Xil"
        if (Test-Path $XilDir) {
            Write-Host "Removing .Xil directory..."
            Remove-Item $XilDir -Recurse -Force
        }
        
        # Remove project directory
        if (Test-Path $ProjectDir) {
            Write-Host "Removing project directory..."
            Remove-Item $ProjectDir -Recurse -Force
        }
        
        # Clean generated block design files (keep only .tcl files)
        Write-Host "Cleaning generated block design files..."
        $BdDir = Join-Path $PSScriptRoot "bd"
        if (Test-Path $BdDir) {
            Get-ChildItem $BdDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne ".tcl" } | Remove-Item -Force -ErrorAction SilentlyContinue
            # Remove empty directories
            Get-ChildItem $BdDir -Recurse -Directory -ErrorAction SilentlyContinue | Sort-Object -Property FullName -Descending | Where-Object { (Get-ChildItem $_.FullName -ErrorAction SilentlyContinue).Count -eq 0 } | Remove-Item -Force -ErrorAction SilentlyContinue
        }
        
        Write-Host "=== CLEAN COMPLETE ===" -ForegroundColor Green
    }

    default {
        Write-Error "Unknown target '$Target'. Available targets: project, export-bd, bitstream, program, status, reset, load, run, open, clean"
    }
}
