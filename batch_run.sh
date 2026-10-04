#!/bin/bash
# Usage: ./batch_run.sh <yaml-file> <rollout-name> <namespace> <condition-label> <num-runs> <fault-modes-comma-separated> <vus-comma-separated> <target-svc>

YAML=$1
ROLLOUT=$2
NAMESPACE=$3
LABEL=$4
RUNS=$5
IFS=',' read -ra FAULTS <<< "$6"
IFS=',' read -ra VUS_LIST <<< "$7"
TARGET_SVC=$8

for FAULT in "${FAULTS[@]}"; do
  for VUS in "${VUS_LIST[@]}"; do
    for i in $(seq 1 $RUNS); do
      RUN_LABEL="${LABEL}_${FAULT}_vus${VUS}_run${i}"
      echo "=== $RUN_LABEL ==="

      kubectl delete -f "$YAML" --ignore-not-found=true
      sleep 5

      # Stage 1: deploy clean baseline, wait for it to stabilize
      # (anchored to the FAULT_MODE key specifically, not any quoted "value: ..." line)
      perl -0pi -e 's/(name:\s*FAULT_MODE\s*\n\s*value:\s*)".*?"/${1}"off"/s' "$YAML"
      kubectl apply -f "$YAML"
      kubectl argo rollouts status "$ROLLOUT" -n "$NAMESPACE" --timeout=120s

      # Stage 2: trigger the actual condition under test, and set the
      # AnalysisTemplate's own VUS to match this run's background load
      perl -0pi -e "s/(name:\s*FAULT_MODE\s*\n\s*value:\s*)\".*?\"/\${1}\"$FAULT\"/s" "$YAML"
      perl -0pi -e "s/(name:\s*vus\s*\n\s*value:\s*)\".*?\"/\${1}\"$VUS\"/s" "$YAML"
      perl -pi -e "s/run-id: \".*?\"/run-id: \"$(date +%s)\"/" "$YAML"
      kubectl apply -f "$YAML"

      kubectl run "k6-${RUN_LABEL//_/-}" -n "$NAMESPACE" --restart=Never --image=grafana/k6:latest \
        --overrides='{"spec":{"volumes":[{"name":"script","configMap":{"name":"k6-script"}}],"containers":[{"name":"k6-'"${RUN_LABEL//_/-}"'","image":"grafana/k6:latest","volumeMounts":[{"name":"script","mountPath":"/scripts"}],"command":["k6","run","--vus","'"$VUS"'","--duration","60s","-e","TARGET='"${TARGET_SVC}"'.demo.svc.cluster.local","/scripts/loadtest.js"]}]}}' \
        > /dev/null 2>&1 &

      ~/canary-research/experiments/run_trial.sh "$ROLLOUT" "$NAMESPACE" "$RUN_LABEL"

      kubectl delete pod "k6-${RUN_LABEL//_/-}" -n "$NAMESPACE" --ignore-not-found=true
      sleep 5
    done
  done
done
echo "Batch complete: $LABEL"