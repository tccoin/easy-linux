#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
claw-submit.sh: multi-partition job submitter for batch and attachable interactive allocations.

Usage:
  ./claw-submit.sh --name <task-name> [options]

Options:
  --name <name>              Task name (without the claw- prefix in job names).
  --mode <mode>              batch | interactive (default: batch)
  --time <HH:MM:SS>          SLURM wall time (default: 04:00:00)
  --hold-time <HH:MM:SS>     Reserved for compatibility; ignored by interactive (default: 00:30:00)
  --cpu <count>             CPUs per task (default: 32)
  --mem <size>               Memory request (default: 256G)
  --gpu <count>              GPU count (default: 1)
  --partition <list>         Comma-separated partitions. Default: spgpu,gpu-rtx6000,gpu_mig40
  --command-file <path>      Shell script to run as the batch payload instead of the default command
  -c, --command <command>     Inline batch payload to run under zsh from the submit directory
  --help                     Show this help message

Behavior:
  - batch: submit redundant jobs across partitions, keep the first one that starts, cancel the rest.
  - interactive: submit redundant jobs across partitions, keep the first one that starts,
    create an inner tmux session on the winning node, auto-run the payload there, and leave the
    session attachable for monitoring/interruption.
EOF
}

NAME="task"
MODE="batch"
TIME="4:00:00"
HOLD_TIME="00:30:00"
CPUS=16
MEM="256G"
GPU=1
ACCOUNT="junzhewu0"
PARTITION_SPEC=""
COMMAND_FILE=""
BATCH_COMMAND_ARG="${BATCH_COMMAND:-}"
SUBMIT_CWD=$(pwd -P)
TASK_DIR="$HOME/tasks"
LOG_DIR="$TASK_DIR/logs"
RUN_DIR="$TASK_DIR/runs"
DATE_TAG=$(date +%b%d | tr 'A-Z' 'a-z')
DEFAULT_PARTITIONS=("spgpu" "gpu-rtx6000" "gpu_mig40")

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift ;;
        --mode) MODE="$2"; shift ;;
        --time) TIME="$2"; shift ;;
        --hold-time) HOLD_TIME="$2"; shift ;;
        --cpu) CPUS="$2"; shift ;;
        --mem) MEM="$2"; shift ;;
        --gpu) GPU="$2"; shift ;;
        --partition) PARTITION_SPEC="$2"; shift ;;
        --command-file) COMMAND_FILE="$2"; shift ;;
        -c|--command) BATCH_COMMAND_ARG="$2"; shift ;;
        --help) usage; exit 0 ;;
        *) BATCH_COMMAND_ARG="$*"; break ;;
    esac
    shift
done

if [[ "$MEM" =~ ^[0-9]+$ ]]; then
    MEM="${MEM}G"
fi

if [[ "$MODE" != "batch" && "$MODE" != "interactive" ]]; then
    echo "Unsupported mode: $MODE"
    exit 1
fi

echo "MODE: $MODE"
echo "TIME: $TIME"
echo "CPU: $CPUS"
echo "MEM: $MEM"
echo "GPU: $GPU"
echo "PARTITION_SPEC: $PARTITION_SPEC"
echo "COMMAND_FILE: $COMMAND_FILE"
echo "SUBMIT_CWD: $SUBMIT_CWD"


partition_gres() {
    local part="$1"
    if [[ "$part" == "gpu_mig40" ]]; then
        echo "gpu:nvidia_a100_80gb_pcie_3g.40gb:$GPU"
    else
        echo "gpu:$GPU"
    fi
}

collect_partitions() {
    local parts=()
    if [[ -n "$PARTITION_SPEC" ]]; then
        IFS=',' read -r -a parts <<< "$PARTITION_SPEC"
    else
        parts=("${DEFAULT_PARTITIONS[@]}")
    fi
    printf '%s\n' "${parts[@]}"
}

DEFAULT_BATCH_COMMAND=$(cat <<'EOF'
zsh -lc 'export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share} && export PYTHONNOUSERSITE=1 && echo "Hello, World!"'
EOF
)

if [[ -n "$COMMAND_FILE" && -n "$BATCH_COMMAND_ARG" ]]; then
    echo "Use either --command-file or --command/-c, not both."
    exit 1
fi

if [[ -n "$COMMAND_FILE" ]]; then
    if [[ ! -f "$COMMAND_FILE" ]]; then
        echo "Command file not found: $COMMAND_FILE"
        exit 1
    fi
    BATCH_COMMAND=$(cat "$COMMAND_FILE")
elif [[ -n "$BATCH_COMMAND_ARG" ]]; then
    BATCH_COMMAND="$BATCH_COMMAND_ARG"
else
    BATCH_COMMAND="$DEFAULT_BATCH_COMMAND"
fi

mkdir -p "$LOG_DIR" "$RUN_DIR"

declare -A JOBS

PARTITIONS=()
while IFS= read -r part; do
    [[ -n "$part" ]] && PARTITIONS+=("$part")
done < <(collect_partitions)

for PART in "${PARTITIONS[@]}"; do
    GRES=$(partition_gres "$PART")
    SBATCH_FILE="$TASK_DIR/${DATE_TAG}_${PART}_${NAME}.sbatch"
    LOG_FILE="$LOG_DIR/${DATE_TAG}_${PART}_${NAME}_%j.log"

    if [[ "$MODE" == "batch" ]]; then
        cat > "$SBATCH_FILE" <<EOF
#!/bin/bash
#SBATCH --job-name=claw-${PART}-${NAME}
#SBATCH --account=$ACCOUNT
#SBATCH --partition=$PART
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$CPUS
#SBATCH --mem=$MEM
#SBATCH --gres=$GRES
#SBATCH --time=$TIME
#SBATCH --output=$LOG_FILE
#SBATCH --gpu_cmode=shared

set -euo pipefail

TASK_DIR="$TASK_DIR"
RUN_DIR="$RUN_DIR"
PARTITION_NAME="$PART"
TASK_NAME="$NAME"
SUBMIT_CWD="$SUBMIT_CWD"
LOG_FILE="$LOG_DIR/${DATE_TAG}_${PART}_${NAME}_\$SLURM_JOB_ID.log"
INFO_FILE="$RUN_DIR/${DATE_TAG}_${PART}_${NAME}_\$SLURM_JOB_ID.info"
RUN_FILE="$RUN_DIR/${DATE_TAG}_${PART}_${NAME}_\$SLURM_JOB_ID.command.sh"
NODE_NAME=\$(hostname -s)

mkdir -p "\$RUN_DIR"

cat > "\$RUN_FILE" <<'CMDEOF'
$BATCH_COMMAND
CMDEOF
chmod +x "\$RUN_FILE"

cat > "\$INFO_FILE" <<INFOEOF
MODE=batch
JOB_ID=\$SLURM_JOB_ID
PARTITION=\$PARTITION_NAME
NODE=\$NODE_NAME
LOG_FILE=\$LOG_FILE
SBATCH_FILE=$SBATCH_FILE
INFO_FILE=\$INFO_FILE
RUN_FILE=\$RUN_FILE
SUBMIT_CWD=\$SUBMIT_CWD
DEFAULT_COMMAND=train_all.sh via gs_world.sif
INFOEOF

ln -sfn "\$INFO_FILE" "$RUN_DIR/latest_${NAME}.info"

echo "[HPC] JOB_ID=\$SLURM_JOB_ID"
echo "[HPC] PARTITION=\$PARTITION_NAME"
echo "[HPC] NODE=\$NODE_NAME"
echo "[HPC] LOG_FILE=\$LOG_FILE"
echo "[HPC] INFO_FILE=\$INFO_FILE"
echo "[HPC] RUN_FILE=\$RUN_FILE"
echo "[HPC] SUBMIT_CWD=\$SUBMIT_CWD"

export SUBMIT_CWD RUN_FILE
exec zsh -lc 'cd "\$SUBMIT_CWD" && source "\$RUN_FILE"'
EOF
    else
        cat > "$SBATCH_FILE" <<EOF
#!/bin/bash
#SBATCH --job-name=claw-${PART}-${NAME}
#SBATCH --account=$ACCOUNT
#SBATCH --partition=$PART
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=$CPUS
#SBATCH --mem=$MEM
#SBATCH --gres=$GRES
#SBATCH --time=$TIME
#SBATCH --output=$LOG_FILE
#SBATCH --gpu_cmode=shared

set -euo pipefail

TASK_DIR="$TASK_DIR"
RUN_DIR="$RUN_DIR"
PARTITION_NAME="$PART"
TASK_NAME="$NAME"
SUBMIT_CWD="$SUBMIT_CWD"
LOG_FILE="$LOG_DIR/${DATE_TAG}_${PART}_${NAME}_\$SLURM_JOB_ID.log"
INFO_FILE="$RUN_DIR/${DATE_TAG}_${PART}_${NAME}_\$SLURM_JOB_ID.info"
RUN_FILE="$RUN_DIR/${DATE_TAG}_${PART}_${NAME}_\$SLURM_JOB_ID.command.sh"
INNER_TMUX="claw-${NAME}"
NODE_NAME=\$(hostname -s)

mkdir -p "\$RUN_DIR"

cat > "\$RUN_FILE" <<'CMDEOF'
$BATCH_COMMAND
CMDEOF
chmod +x "\$RUN_FILE"

tmux kill-session -t "\$INNER_TMUX" 2>/dev/null || true
export SUBMIT_CWD RUN_FILE
TMUX_CMD="zsh -lc 'cd \"\$SUBMIT_CWD\" && source \"\$RUN_FILE\"; echo; echo \"[HPC] Task finished. Dropping to interactive shell for debugging...\"; exec zsh'"
tmux new-session -d -s "\$INNER_TMUX" "\$TMUX_CMD"

cat > "\$INFO_FILE" <<INFOEOF
MODE=interactive
JOB_ID=\$SLURM_JOB_ID
PARTITION=\$PARTITION_NAME
NODE=\$NODE_NAME
LOG_FILE=\$LOG_FILE
INFO_FILE=\$INFO_FILE
RUN_FILE=\$RUN_FILE
SUBMIT_CWD=\$SUBMIT_CWD
INNER_TMUX=\$INNER_TMUX
ATTACH_VIA_SSH=ssh \$NODE_NAME -t 'tmux attach -t \$INNER_TMUX'
ATTACH_VIA_SRUN=srun --jobid \$SLURM_JOB_ID --overlap --pty bash -lc 'tmux attach -t \$INNER_TMUX || tmux new -As \$INNER_TMUX'
SBATCH_FILE=$SBATCH_FILE
INFOEOF

ln -sfn "\$INFO_FILE" "$RUN_DIR/latest_${NAME}.info"

echo "[HPC] INTERACTIVE RUN READY"
echo "[HPC] JOB_ID=\$SLURM_JOB_ID"
echo "[HPC] PARTITION=\$PARTITION_NAME"
echo "[HPC] NODE=\$NODE_NAME"
echo "[HPC] LOG_FILE=\$LOG_FILE"
echo "[HPC] INFO_FILE=\$INFO_FILE"
echo "[HPC] RUN_FILE=\$RUN_FILE"
echo "[HPC] INNER_TMUX=\$INNER_TMUX"
echo "[HPC] ATTACH_VIA_SSH=ssh \$NODE_NAME -t 'tmux attach -t \$INNER_TMUX'"
echo "[HPC] ATTACH_VIA_SRUN=srun --jobid \$SLURM_JOB_ID --overlap --pty bash -lc 'tmux attach -t \$INNER_TMUX || tmux new -As \$INNER_TMUX'"
echo "[HPC] AUTO_START=enabled"

while tmux has-session -t "\$INNER_TMUX" 2>/dev/null; do
    sleep 5
done
EOF
    fi

    # Fixed syntax by using explicit shell tokens for backticks/subshells
    if ! JID_OUT=$(sbatch "$SBATCH_FILE" 2>&1); then
        echo "[HPC][WARN] Submission failed for $PART"
        echo "$JID_OUT"
        continue
    fi

    JOB_ID=$(echo "$JID_OUT" | awk '/Submitted batch job/ {print $4; exit}')
    if [[ -z "$JOB_ID" ]]; then
        echo "[HPC][WARN] Could not parse job id for $PART"
        echo "$JID_OUT"
        continue
    fi

    JOBS["$PART"]="$JOB_ID"
    echo "[HPC] Submitted to $PART: Job ID $JOB_ID"
done

if [[ "${#JOBS[@]}" -eq 0 ]]; then
    echo "[HPC][ERROR] No jobs were submitted successfully."
    exit 1
fi

echo "[HPC] Monitoring status... (Will cancel others if one starts)"
echo "[HPC] Press q to stop waiting and cancel queued jobs."

ACTIVE_JOB=""
ACTIVE_PART=""
ACTIVE_NODE=""

cancel_queued_jobs() {
    local reason="$1"
    local canceled=0
    echo "[HPC] Exit requested: $reason"

    if [[ -n "$ACTIVE_JOB" ]]; then
        echo "[HPC] Active job $ACTIVE_JOB already started; leaving it running."
        return 0
    fi

    for PART in "${!JOBS[@]}"; do
        local jid="${JOBS[$PART]}"
        local status
        status=$(squeue -h -j "$jid" -o "%t" 2>/dev/null || true)

        if [[ -z "$status" ]]; then
            echo "[HPC] Job $jid ($PART) already left squeue."
            continue
        fi

        if [[ "$status" == "R" ]]; then
            echo "[HPC] Job $jid ($PART) is already running; not canceling."
            continue
        fi

        echo "[HPC] Canceling queued job $jid ($PART), status=$status"
        scancel "$jid" || true
        canceled=1
    done

    if [[ "$canceled" -eq 0 ]]; then
        echo "[HPC] No queued jobs needed cancellation."
    fi
}

handle_queue_interrupt() {
    cancel_queued_jobs "Ctrl-C"
    exit 130
}

wait_for_next_poll() {
    local key=""

    if [[ ! -t 0 ]]; then
        sleep 5
        return 0
    fi

    if IFS= read -r -s -n 1 -t 5 key; then
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            cancel_queued_jobs "keyboard q"
            exit 0
        fi
    fi
}

trap 'handle_queue_interrupt' INT

while true; do
    REPORT=""

    for PART in "${!JOBS[@]}"; do
        JID=${JOBS[$PART]}
        INFO=$(squeue -h -j "$JID" -o "%t|%N|%S" 2>/dev/null || true)
        if [[ -z "$INFO" ]]; then
            REPORT+="  - $PART (ID $JID): no longer in squeue\n"
            continue
        fi

        STATUS=$(echo "$INFO" | cut -d'|' -f1)
        NODE=$(echo "$INFO" | cut -d'|' -f2)
        START_TIME=$(echo "$INFO" | cut -d'|' -f3)

        if [[ "$STATUS" == "R" ]]; then
            ACTIVE_JOB="$JID"
            ACTIVE_PART="$PART"
            ACTIVE_NODE="$NODE"
            break
        fi

        REPORT+="  - $PART (ID $JID): Status $STATUS, Est. Start: $START_TIME\n"
    done

    if [[ -n "$ACTIVE_JOB" ]]; then
        echo "[SUCCESS] Job $ACTIVE_JOB started on $ACTIVE_PART ($ACTIVE_NODE)"
        for PART in "${!JOBS[@]}"; do
            JID=${JOBS[$PART]}
            if [[ "$JID" != "$ACTIVE_JOB" ]]; then
                echo "[HPC] Canceling redundant job $JID ($PART)..."
                scancel "$JID" || true
            fi
        done

        WIN_LOG_FILE="$LOG_DIR/${DATE_TAG}_${ACTIVE_PART}_${NAME}_${ACTIVE_JOB}.log"
        WIN_INFO_FILE="$RUN_DIR/${DATE_TAG}_${ACTIVE_PART}_${NAME}_${ACTIVE_JOB}.info"

        echo "[HPC] ACTIVE_JOB=$ACTIVE_JOB"
        echo "[HPC] ACTIVE_PARTITION=$ACTIVE_PART"
        echo "[HPC] ACTIVE_NODE=$ACTIVE_NODE"
        echo "[HPC] LOG_FILE=$WIN_LOG_FILE"
        echo "[HPC] INFO_FILE=$WIN_INFO_FILE"
        echo "[HPC] QUICK_ATTACH=cd $RUN_DIR && ./claw-attach.sh --latest"

        if [[ "$MODE" == "interactive" ]]; then
            for _ in $(seq 1 60); do
                [[ -f "$WIN_INFO_FILE" ]] && break
                sleep 1
            done

            if [[ -f "$WIN_INFO_FILE" ]]; then
                echo "[HPC] --- Interactive Run Info ---"
                cat "$WIN_INFO_FILE"
            else
                echo "[WARN] Interactive info file not ready yet: $WIN_INFO_FILE"
            fi
        fi

        exec zsh
    fi

    echo -e "\n[PENDING] $(date '+%H:%M:%S')\n$REPORT"
    wait_for_next_poll
done
