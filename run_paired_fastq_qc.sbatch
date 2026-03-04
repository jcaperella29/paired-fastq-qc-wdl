#!/usr/bin/env bash
#SBATCH --job-name=paired_fastq_qc_cromwell
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --output=cromwell-%j.out
#SBATCH --error=cromwell-%j.err

set -euo pipefail

module load apptainer 2>/dev/null || true
module load singularity 2>/dev/null || true

# Pick runtime
if command -v apptainer >/dev/null 2>&1; then
  RUNTIME="apptainer"
elif command -v singularity >/dev/null 2>&1; then
  RUNTIME="singularity"
else
  echo "ERROR: Neither apptainer nor singularity found in PATH." >&2
  exit 1
fi

REPO_DIR="${SLURM_SUBMIT_DIR:-$PWD}"
SIF="$REPO_DIR/hpc/cromwell_84.sif"

# Recommended: cache to scratch (edit path for your cluster)
export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-/scratch/$USER/singularity_cache}"
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-/scratch/$USER/singularity_tmp}"
mkdir -p "$SINGULARITY_CACHEDIR" "$SINGULARITY_TMPDIR"

echo "Repo:   $REPO_DIR"
echo "SIF:    $SIF"
echo "Runtime:$RUNTIME"

$RUNTIME exec --bind "$REPO_DIR:/work" "$SIF" bash -lc '
  cd /work
  java -Dconfig.file=/work/hpc/cromwell_slurm.conf -jar /opt/cromwell/cromwell.jar \
    run /work/paired_fastq_qc.wdl -i /work/inputs/paired_fastq_inputs.json
'
