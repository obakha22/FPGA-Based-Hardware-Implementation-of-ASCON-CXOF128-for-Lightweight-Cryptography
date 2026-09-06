# ASCON-CXOF128 KAT sweep evidence

This folder contains the transcript, testbench, scripts, and generated data used
for the ASCON-CXOF128 1089-vector KAT sweep.

## Reproduce

Run from the Vivado project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_cxof_kat_sweep.ps1
```

The expected final lines are:

```text
Completed 1089 ASCON-CXOF128 KAT vectors.
Total errors: 0
PASS: complete ASCON-CXOF128 KAT sweep matched.
Parsed 1089 performance records.
```

## Files

- `cxof_sweep_simulate.log`: Vivado xsim transcript from the passing full sweep.
- `tb_ascon_cxof128_kat_sweep.v`: file-driven KAT sweep testbench.
- `run_cxof_kat_sweep.ps1`: compile, elaborate, simulate, and parse workflow.
- `generate_cxof_kat_mem.ps1`: converts the official KAT text into HDL-friendly words.
- `parse_cxof_performance.ps1`: extracts `PERF,...` lines into CSV summaries.
- `LWC_CXOF_KAT_128_512.txt`: official 512-bit-output ASCON-CXOF128 KAT vectors.
- `cxof_kat_vectors.mem`: generated simulation vector memory file.
- `cxof_kat_performance_sweep.csv`: per-vector measured cycle/throughput results.
- `cxof_kat_performance_by_message_size.csv`: grouped performance summary.
