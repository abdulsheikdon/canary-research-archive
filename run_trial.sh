#!/bin/bash
# Usage: ./run_trial.sh <rollout-name> <namespace> <label-for-this-run>

ROLLOUT=$1
NAMESPACE=$2
LABEL=$3
LOGFILE=~/canary-research/experiments/results.csv


if [ ! -f "$LOGFILE" ]; then
  echo "label,start_time,end_time,duration_seconds,result" > "$LOGFILE"
fi

echo "Starting trial: $LABEL"
START=$(date +%s)


kubectl argo rollouts status "$ROLLOUT" -n "$NAMESPACE" --timeout 600s
RESULT=$?

END=$(date +%s)
DURATION=$((END - START))

if [ $RESULT -eq 0 ]; then
  STATUS="healthy"
else
  STATUS="failed_or_timeout"
fi

echo "Trial finished: $STATUS in ${DURATION}s"
echo "$LABEL,$START,$END,$DURATION,$STATUS" >> "$LOGFILE"