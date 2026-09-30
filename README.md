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
