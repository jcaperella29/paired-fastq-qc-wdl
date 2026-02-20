# Paired FASTQ QC (WDL + Cromwell)

A small WDL workflow that runs basic QC for paired-end FASTQ files:
- per-sample read counts (R1/R2)
- FastQC on R1/R2
- MultiQC report aggregating FastQC outputs across all samples

## Requirements
- Java (to run Cromwell)
- `cromwell.jar`
- Docker (workflow uses docker images in task runtimes)
- Input FASTQ files accessible from the machine running Cromwell

## Run
From the repo directory:

```bash
java -jar cromwell.jar run paired_fastq_qc.wdl --inputs inputs/paired_fastq_inputs.json
