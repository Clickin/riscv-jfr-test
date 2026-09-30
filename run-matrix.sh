#!/usr/bin/env bash
# usage: run-matrix.sh <label> <runs-per-case> [rounds]
# Runs PureJavaVt under three JFR configurations and counts JVM crashes.
set -u
label=${1:?label}; runs=${2:-20}; rounds=${3:-50}
out=results/$label; mkdir -p "$out"
J=${JAVA_HOME:+$JAVA_HOME/bin/}java
JC=${JAVA_HOME:+$JAVA_HOME/bin/}javac
major=$($J -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p')
if [ "${major:-0}" -lt 25 ]; then
  echo "ERROR: need JDK 25, found '$($J -version 2>&1 | head -1)' (JAVA_HOME=${JAVA_HOME:-unset})" >&2
  exit 2
fi
{
  echo "## $label"
  echo '```'
  uname -a
  grep -m1 -E '^(isa|model name|uarch|mmu)' /proc/cpuinfo || true
  grep -E '^(isa|uarch|mvendorid|marchid)' /proc/cpuinfo | sort -u || true
  $J -version 2>&1
  $J -XX:+PrintFlagsFinal -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions -version 2>/dev/null \
    | grep -E ' Use(RVV|Zfh|Zvfh|Zba|Zbb|Zbs|Zvbb|Zicboz|Zacas|Zvkn) ' | awk '{print $2"="$4}' | tr '\n' ' '
  echo; echo '```'
} | tee "$out/env.md"
$JC -d "$out" PureJavaVt.java || exit 2

BASE=(-Djdk.virtualThreadScheduler.parallelism=1 -Djdk.virtualThreadScheduler.maxPoolSize=1 -cp "$out")
declare -A OPTS=(
  [jfr-off]=""
  [jfr-on]="-XX:StartFlightRecording=filename=@DIR@/rec.jfr,dumponexit=true,maxsize=20m"
  [jfr-on-nosampling]="-XX:StartFlightRecording=filename=@DIR@/rec.jfr,dumponexit=true,maxsize=20m,jdk.ExecutionSample#enabled=false,jdk.NativeMethodSample#enabled=false"
)
{ echo; echo "| case | runs | pass | crash (hs_err) | other failure |"; echo "|---|---|---|---|---|"; } > "$out/summary.md"
for c in jfr-off jfr-on jfr-on-nosampling; do
  pass=0; crash=0; other=0
  for i in $(seq 1 "$runs"); do
    d="$out/$c-$i"; mkdir -p "$d"
    o=${OPTS[$c]//@DIR@/$d}
    # shellcheck disable=SC2086
    timeout 600 $J "${BASE[@]}" -XX:ErrorFile="$d/hs_err_%p.log" $o PureJavaVt "$rounds" >"$d/stdout.txt" 2>"$d/stderr.txt"
    rc=$?
    if ls "$d"/hs_err_*.log >/dev/null 2>&1; then crash=$((crash+1)); echo "$c #$i CRASH rc=$rc"
    elif [ $rc -eq 0 ] && grep -q PURE-PASS "$d/stdout.txt"; then pass=$((pass+1)); rm -rf "$d"
    else other=$((other+1)); echo "$c #$i OTHER rc=$rc"; fi
  done
  echo "| $c | $runs | $pass | $crash | $other |" >> "$out/summary.md"
done
cat "$out/summary.md"
{ cat "$out/env.md"; cat "$out/summary.md"; } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
exit 0
