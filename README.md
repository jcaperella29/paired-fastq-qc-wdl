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

🧱 Design Goals

This workflow emphasizes:

reproducibility

portability

parallel scalability

clean sample bookkeeping

compatibility with larger bioinformatics platforms

It is intentionally lightweight but structured to serve as a production-style QC building block.
