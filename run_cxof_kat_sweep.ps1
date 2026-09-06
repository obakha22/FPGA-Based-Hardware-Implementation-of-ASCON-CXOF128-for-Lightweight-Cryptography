param(
    [string]$VivadoBin = "D:\Xilinx\Vivado\2023.2\bin"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$workDir = Join-Path $root "project_1.sim\sim_1\behav\xsim"

$xvlog = Join-Path $VivadoBin "xvlog.bat"
$xelab = Join-Path $VivadoBin "xelab.bat"
$xsim = Join-Path $VivadoBin "xsim.bat"

foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Vivado tool not found: $tool. Pass -VivadoBin with your Vivado bin directory."
    }
}

Push-Location $root
try {
    & (Join-Path $PSScriptRoot "generate_cxof_kat_mem.ps1")
}
finally {
    Pop-Location
}

Push-Location $workDir
try {
    & $xvlog --relax `
        "../../../../project_1.srcs/sources_1/new/ascon_cxof128_core.v" `
        "../../../../project_1.srcs/sources_1/new/ascon_permutation_iterative.v" `
        "../../../../project_1.srcs/sources_1/new/ascon_round.v" `
        "../../../../project_1.srcs/sim_1/new/tb_ascon_cxof128_kat_sweep.v" `
        -log cxof_sweep_compile.log
    if ($LASTEXITCODE -ne 0) {
        throw "CXOF KAT compilation failed."
    }

    & $xelab --debug typical --relax --mt 2 `
        --snapshot tb_ascon_cxof128_kat_sweep_behav `
        work.tb_ascon_cxof128_kat_sweep `
        -log cxof_sweep_elaborate.log
    if ($LASTEXITCODE -ne 0) {
        throw "CXOF KAT elaboration failed."
    }

    & $xsim tb_ascon_cxof128_kat_sweep_behav `
        -runall `
        -log cxof_sweep_simulate.log
    if ($LASTEXITCODE -ne 0) {
        throw "CXOF KAT simulation failed."
    }
}
finally {
    Pop-Location
}

Push-Location $root
try {
    & (Join-Path $PSScriptRoot "parse_cxof_performance.ps1")
}
finally {
    Pop-Location
}
