#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
claw-attach.sh: select a live SLURM job via squeue and attach to it.

Usage:
  ./claw-attach.sh [--latest]

Options:
  --latest       Compatibility flag. Running jobs are already auto-prioritized.
  --dir <path>   Compatibility flag. Ignored because selection now comes from squeue.
  --help         Show this help message

Environment:
  CLAW_ATTACH_DRY_RUN=1   Print the chosen attach command instead of executing it.
EOF
}

AUTO_LATEST=0

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dir)
            shift
            [[ "$#" -gt 0 ]] || { echo "Missing path after --dir" >&2; exit 1; }
            ;;
        --latest)
            AUTO_LATEST=1
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown parameter passed: $1" >&2
            exit 1
            ;;
    esac
    shift
done

fetch_jobs() {
    local state="$1"
    squeue -u "$USER" -h -t "$state" -o "%i|%P|%C|%b|%m|%N|%j"
}

print_job_line() {
    local line="$1"
    local prefix="${2:-}"
    IFS='|' read -r job_id partition cpus gpus ram node job_name <<< "$line"
    printf "%sjob id: %s, partition: %s, cpu: %s, gpu: %s, ram: %s" "$prefix" "$job_id" "$partition" "$cpus" "${gpus:-n/a}" "$ram"
    if [[ -n "$node" && "$node" != "(null)" && "$node" != "n/a" ]]; then
        printf ", node: %s" "$node"
    fi
    if [[ -n "$job_name" ]]; then
        printf ", name: %s" "$job_name"
    fi
    printf "\n"
}

choose_running_job() {
    local -n job_lines_ref=$1

    if (( ${#job_lines_ref[@]} == 1 )); then
        echo "Detected 1 running job, attaching automatically:" >&2
        print_job_line "${job_lines_ref[0]}" >&2
        echo "${job_lines_ref[0]}"
        return
    fi

    echo "Detected multiple running jobs:" >&2
    local idx=1
    local line
    for line in "${job_lines_ref[@]}"; do
        print_job_line "$line" "  ${idx}) " >&2
        idx=$((idx + 1))
    done

    while true; do
        read -r -p "Select a job to attach [1-${#job_lines_ref[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#job_lines_ref[@]} )); then
            echo "${job_lines_ref[choice-1]}"
            return
        fi
        echo "Invalid selection." >&2
    done
}

derive_inner_tmux() {
    local partition="$1"
    local job_name="$2"
    local prefix="claw-${partition}-"

    if [[ "$job_name" == "$prefix"* ]]; then
        echo "claw-${job_name#$prefix}"
        return
    fi

    if [[ "$job_name" == claw-* ]]; then
        echo "claw-${job_name#claw-}"
        return
    fi

    echo ""
}

run_attach() {
    local job_id="$1"
    local partition="$2"
    local node="$3"
    local job_name="$4"
    local inner_tmux
    inner_tmux=$(derive_inner_tmux "$partition" "$job_name")

    if [[ -n "$node" && "$node" != "(null)" && "$node" != "n/a" ]]; then
        local ssh_cmd="ssh -t ${node} \"if [[ -n '${inner_tmux}' ]] && tmux has-session -t '${inner_tmux}' 2>/dev/null; then tmux attach -t '${inner_tmux}'; else exec bash -l; fi\""
        if [[ "${CLAW_ATTACH_DRY_RUN:-0}" == "1" ]]; then
            echo "DRY_RUN attach via ssh: ${ssh_cmd}"
            return 0
        fi
        exec ssh -t "$node" "if [[ -n '$inner_tmux' ]] && tmux has-session -t '$inner_tmux' 2>/dev/null; then tmux attach -t '$inner_tmux'; else exec bash -l; fi"
    fi

    local srun_cmd="srun --jobid ${job_id} --overlap --pty bash -lc \"if [[ -n '${inner_tmux}' ]] && tmux has-session -t '${inner_tmux}' 2>/dev/null; then tmux attach -t '${inner_tmux}'; elif [[ -n '${inner_tmux}' ]]; then tmux new -As '${inner_tmux}'; else exec bash; fi\""
    if [[ "${CLAW_ATTACH_DRY_RUN:-0}" == "1" ]]; then
        echo "DRY_RUN attach via srun: ${srun_cmd}"
        return 0
    fi
    exec srun --jobid "$job_id" --overlap --pty bash -lc "if [[ -n '$inner_tmux' ]] && tmux has-session -t '$inner_tmux' 2>/dev/null; then tmux attach -t '$inner_tmux'; elif [[ -n '$inner_tmux' ]]; then tmux new -As '$inner_tmux'; else exec bash; fi"
}

mapfile -t running_jobs < <(fetch_jobs "RUNNING")

if (( ${#running_jobs[@]} > 0 )); then
    selected_line=$(choose_running_job running_jobs)
    IFS='|' read -r selected_job_id selected_partition selected_cpus selected_gpus selected_ram selected_node selected_name <<< "$selected_line"
    run_attach "$selected_job_id" "$selected_partition" "$selected_node" "$selected_name"
    exit 0
fi

mapfile -t pending_jobs < <(fetch_jobs "PENDING")

if (( ${#pending_jobs[@]} > 0 )); then
    echo "No running jobs found. Pending jobs:" 
    for line in "${pending_jobs[@]}"; do
        print_job_line "$line" "  - "
    done
    exit 0
fi

echo "No submitted jobs found"
