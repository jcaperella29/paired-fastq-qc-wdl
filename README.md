Paired FASTQ QC (WDL + Cromwell)

A containerized WDL 1.1 workflow for scalable quality control of paired-end FASTQ files using Cromwell.

This workflow is designed to demonstrate modern pipeline engineering patterns including struct-based inputs, scatter parallelization, and MultiQC aggregation.

🚀 Features

The workflow performs:

✅ Per-sample read counts (R1/R2)

✅ FastQC on each FASTQ

✅ MultiQC aggregation across all samples

✅ Input validation and sample ID checks

✅ Scatter parallelization over samples

✅ Structured sample manifest generation

✅ Fully containerized tasks

🧠 Engineering highlights

Uses WDL structs (FastqPair) to keep paired reads together

Uses scatter for parallel per-sample QC

Uses flatten() to aggregate FastQC outputs

Produces cohort-level QC summary

Designed to run on:

local Cromwell

HPC environments

cloud backends (with config)

This is intended as a foundation QC module that can plug into larger omics pipelines.

📂 Workflow Outputs

Key outputs include:

Output	Description
merged_qc.tsv	Per-sample read counts
multiqc_report.html	Aggregated QC dashboard
FastQC reports	Per-sample quality reports
manifest files	Structured sample tracking

Outputs are written under the Cromwell execution directory.

🧰 Requirements

Java (for Cromwell)

cromwell.jar (v84 tested)

Docker (tasks run in containers)

FASTQ files accessible to the runtime environment
▶️ Run the Workflow

From the repository root:
in bash 
java -jar cromwell.jar run paired_fastq_qc.wdl \
  --inputs inputs/paired_fastq_inputs.json

  📥 Input Format

Inputs are provided as an array of paired FASTQs:

an example would be 

{
  "paired_fastq_qc_workflow.pairs": [
    {
      "sample_id": "sampleA",
      "r1": "fastq/sampleA_R1.fastq.gz",
      "r2": "fastq/sampleA_R2.fastq.gz"
    }
  ]
}

🧪 Example Directory Layout
paired-fastq-qc-wdl/
├── paired_fastq_qc.wdl
├── inputs/
│   └── paired_fastq_inputs.json
├── fastq/
│   ├── sampleA_R1.fastq.gz
│   └── sampleA_R2.fastq.gz
└── README.md

🔍 Viewing Results
run this in bash
find cromwell-executions -name "multiqc_report.html"

Open the report in your browser:

explorer.exe <path-to-report>

🖥️ Running on HPC (Slurm + Singularity/Apptainer)

This repo supports running Cromwell on an HPC cluster using Slurm for scheduling and Singularity/Apptainer for container execution.

✅ What this does

You submit one Slurm job that launches Cromwell (the “driver” job)

Cromwell then submits one Slurm job per WDL task

Each task runs inside a container image via docker://... pulled through Singularity/Apptainer

Tip: The first run can be slow if container images need to be pulled and cached. Subsequent runs are usually much faster.

📌 Prerequisites (HPC)

Slurm (sbatch, squeue, scancel)

Singularity or Apptainer available on compute nodes

Java available inside the Cromwell container (recommended) or on the host

A Cromwell container image (example provided)

📁 Expected HPC directory layout

Example:


paired-fastq-qc-wdl/
├── paired_fastq_qc.wdl
├── inputs/
│   └── paired_fastq_inputs.json
├── fastq/
│   ├── sampleA_R1.fastq.gz
│   └── sampleA_R2.fastq.gz

    ├── run_paired_fastq_qc.sbatch
    ├── cromwell_slurm.conf
    └── cromwell_84.sif


▶️ Run on HPC

From the repo root:
sbatch hpc/run_paired_fastq_qc.sbatch

Monitor:

squeue -u $USER

🧊 Container cache (highly recommended)

To avoid repeated slow container pulls/builds, set Singularity cache directories to fast storage (scratch) in the sbatch script:
export SINGULARITY_CACHEDIR="/scratch/$USER/singularity_cache"
export SINGULARITY_TMPDIR="/scratch/$USER/singularity_tmp"
mkdir -p "$SINGULARITY_CACHEDIR" "$SINGULARITY_TMPDIR"


This dramatically improves performance on most clusters.

⚙️ Slurm config notes (partition/account/time)

The Slurm backend config supports passing raw Slurm flags through WDL runtime attributes:


Example inside a task:


runtime {
  cpu: 1
  memory: "2G"
  time: "--time=00:30:00"
  queue: "--partition=debug"
  account: "--account=myacct"
  docker: "quay.io/biocontainers/fastqc:0.11.9--0"
}

If you omit them, cluster defaults are used.

find cromwell-executions -name "multiqc_report.html"

explorer.exe <path-to-report>

🛑 Common HPC issue: Cromwell job killed by walltime

If the Slurm driver job hits its time limit, you may see:

CANCELLED DUE TO TIME LIMIT

Fix: increase the walltime in hpc/run_paired_fastq_qc.sbatch, for example:
🧱 Design Goals




This workflow emphasizes:

reproducibility

portability

parallel scalability

clean sample bookkeeping

compatibility with larger bioinformatics platforms

It is intentionally lightweight but structured to serve as a production-style QC building block.
