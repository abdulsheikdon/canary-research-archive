#!/bin/bash
set -e

BASE=~/canary-research/experiments
LOGS="$BASE/logs"
mkdir -p "$LOGS"
cd "$BASE"

RUNS=20
FAULTS_ALL="off,errors,latency,memory_leak,crash_loop,downstream_db_slow"
FAULTS_LOADSWEEP="off,errors"

echo ">>> Pre-flight check"
kubectl get pods -n demo | grep demo-db || { echo "Postgres not running — aborting"; exit 1; }
kubectl delete analysisrun --all -n demo
kubectl delete job --all -n demo

echo ">>> Phase A: canary"
"$BASE/batch_run.sh" canary-level1.yaml exp-canary demo canary_level1 $RUNS "$FAULTS_ALL" "10" exp-canary-svc > "$LOGS/canary_level1.log" 2>&1
echo "canary_level1 done — $(tail -1 $BASE/results.csv)"

"$BASE/batch_run.sh" canary-level2.yaml exp-canary demo canary_level2 $RUNS "$FAULTS_ALL" "10" exp-canary-svc > "$LOGS/canary_level2.log" 2>&1
echo "canary_level2 done — $(tail -1 $BASE/results.csv)"

"$BASE/batch_run.sh" canary-level3.yaml exp-canary demo canary_level3 $RUNS "$FAULTS_ALL" "10" exp-canary-svc > "$LOGS/canary_level3.log" 2>&1
echo "canary_level3 done — $(tail -1 $BASE/results.csv)"

echo ">>> Phase B: blue/green"
"$BASE/batch_run.sh" bluegreen-level1.yaml exp-bluegreen demo bluegreen_level1 $RUNS "$FAULTS_ALL" "10" exp-bg-preview > "$LOGS/bluegreen_level1.log" 2>&1
echo "bluegreen_level1 done — $(tail -1 $BASE/results.csv)"

"$BASE/batch_run.sh" bluegreen-level2.yaml exp-bluegreen demo bluegreen_level2 $RUNS "$FAULTS_ALL" "10" exp-bg-preview > "$LOGS/bluegreen_level2.log" 2>&1
echo "bluegreen_level2 done — $(tail -1 $BASE/results.csv)"

"$BASE/batch_run.sh" bluegreen-level3.yaml exp-bluegreen demo bluegreen_level3 $RUNS "$FAULTS_ALL" "10" exp-bg-preview > "$LOGS/bluegreen_level3.log" 2>&1
echo "bluegreen_level3 done — $(tail -1 $BASE/results.csv)"

echo ">>> Phase C: load sweep"
"$BASE/batch_run.sh" canary-level3.yaml exp-canary demo canary_l3_loadsweep $RUNS "$FAULTS_LOADSWEEP" "2,10,30" exp-canary-svc > "$LOGS/canary_loadsweep.log" 2>&1
echo "canary_loadsweep done — $(tail -1 $BASE/results.csv)"

"$BASE/batch_run.sh" bluegreen-level3.yaml exp-bluegreen demo bg_l3_loadsweep $RUNS "$FAULTS_LOADSWEEP" "2,10,30" exp-bg-preview > "$LOGS/bg_loadsweep.log" 2>&1
echo "bg_loadsweep done — $(tail -1 $BASE/results.csv)"

echo ">>> ALL PHASES COMPLETE"
echo "Total rows: $(wc -l < $BASE/results.csv)"
