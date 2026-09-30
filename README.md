# riscv64: JFR sampling + virtual threads crash reproducer

Pure-JDK reproducer (no JNI, no third-party code) for random JVM crashes seen in
`libjvm` continuation thaw/deopt code (and once in `libz`) when a JDK 25 riscv64 JVM
runs virtual threads on a single carrier with JFR enabled **under QEMU user-mode**.

The point of this repository is to answer one question: **does it also crash on real riscv64
hardware?** If not, this is a QEMU issue; if yes, an OpenJDK issue.

`run-matrix.sh` runs `PureJavaVt` N times in three configurations and counts crashes:
`jfr-off`, `jfr-on` (default profile), `jfr-on-nosampling`
(`jdk.ExecutionSample` and `jdk.NativeMethodSample` disabled).

Jobs (see `.github/workflows/repro.yml`):

* `native-riscv64` - `ubuntu-24.04-riscv` (RISE native runner; needs the RISE runner GitHub App installed)
* `qemu-riscv64` - QEMU user-mode via `uraimo/run-on-arch-action`, as used by the sqlite-jdbc CI

The environment (cpuinfo ISA, JVM `UseRVV`/`UseZfh`... flags) is printed with each result,
because the native and emulated CPUs may expose different extensions.

## Results (2026-09-30)

| environment | case | crashes |
|---|---|---|
| QEMU user-mode (GitHub-hosted, Ubuntu 26.04 guest, JDK 25.0.4.1) | JFR off | 0 / 12 |
| | JFR on (20 ms default) | 0 / 12 (1 JFR-start failure) |
| | JFR on, sampling events off | 0 / 12 |
| | JFR on, 1 ms sampling | **26 / 28** |
| | JFR on, 1 ms sampling, `-XX:-UseRVV` | **16 / 16** |
| RISE native runner (`rv64imafdcsu`, kernel 5.10, no RVV/Zb*) | all four cases, 15 runs x 400 rounds each | **0 / 60** (1 ms case: 0 / 15) |

One QEMU crash has exactly the signature seen in the original sqlite-jdbc CI:
`libjvm.so+0x6406b8  frame::interpreter_frame_method() const+0xe` (SIGSEGV).

Caveat: the native hardware exposes neither RVV nor Zba/Zbb/Zbs/Zfh, so this does not
separate "QEMU emulation" from "guest system libraries using RVV". JVM-side RVV
(`-XX:-UseRVV`) is ruled out.
