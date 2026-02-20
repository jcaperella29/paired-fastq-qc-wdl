version 1.0

# ---- Struct to keep paired reads + sample id together ----
struct FastqPair {
  String sample_id
  File r1
  File r2
}

task pair_qc {
  input {
    FastqPair pair
  }

  command <<<
    set -euo pipefail

    # (optional but better if gz) read counts
    # r1_reads=$(zcat "~{pair.r1}" | wc -l); r1_reads=$((r1_reads/4))
    # r2_reads=$(zcat "~{pair.r2}" | wc -l); r2_reads=$((r2_reads/4))

    l1=$(wc -l < "~{pair.r1}")
    l2=$(wc -l < "~{pair.r2}")
    r1_reads=$((l1 / 4))
    r2_reads=$((l2 / 4))

    echo -e "sample_id\tr1_reads\tr2_reads" > counts.tsv
    echo -e "~{pair.sample_id}\t${r1_reads}\t${r2_reads}" >> counts.tsv

    mkdir -p fastqc_out
    fastqc -q -o fastqc_out "~{pair.r1}" "~{pair.r2}"

    # debug breadcrumb (optional but useful once)
    ls -lah fastqc_out
  >>>

  output {
    File counts_tsv = "counts.tsv"
    Array[File] fastqc_zips = glob("fastqc_out/*_fastqc.zip")
    Array[File] fastqc_htmls = glob("fastqc_out/*_fastqc.html")
  }
runtime {
  cpu: 1
  memory: "2G"
  docker: "quay.io/biocontainers/fastqc:0.11.9--0"
}
 }

task merge_counts {
  input {
    Array[File] counts
  }

  command <<<
    set -euo pipefail
    # Take header from first file, then append all data rows from each file
    head -n 1 "~{counts[0]}" > merged_qc.tsv
    for f in ~{sep=' ' counts}; do
      tail -n +2 "$f" >> merged_qc.tsv
    done
  >>>

  output {
    File merged_qc = "merged_qc.tsv"
  }
runtime {
  cpu: 1
  memory: "1G"
  docker: "ubuntu:22.04"
}
 }

task multiqc_local {
  input {
    Array[File] fastqc_zips
  }

  command <<<
    set -euo pipefail

    mkdir -p fastqc_inputs multiqc_out

    # Fail early if the array is empty
    if [ ~{length(fastqc_zips)} -eq 0 ]; then
      echo "ERROR: fastqc_zips is empty; MultiQC has nothing to summarize." >&2
      exit 1
    fi

    # Link every zip into a directory (MultiQC wants a directory / analysis root)
    for z in ~{sep=" " fastqc_zips}; do
      ln -sf "$z" fastqc_inputs/
    done

    # IMPORTANT: give MultiQC the directory, not nothing
    multiqc -q -o multiqc_out fastqc_inputs
  >>>

  output {
    File html_report = "multiqc_out/multiqc_report.html"
    Array[File] reports = glob("multiqc_out/*")
  }
runtime {
  cpu: 1
  memory: "2G"
  docker: "quay.io/biocontainers/multiqc:1.14--pyhdfd78af_0"
}
 }
workflow paired_fastq_qc_workflow {
  input {
    Array[FastqPair] pairs
  }

  scatter (p in pairs) {
    call pair_qc {
      input:
        pair = p
    }
  }

  call merge_counts {
    input:
      counts = pair_qc.counts_tsv
  }

  # scatter makes fastqc_zips an Array[Array[File]]; flatten makes it Array[File]
  call multiqc_local as multiqc_local_call {
    input:
      fastqc_zips = flatten(pair_qc.fastqc_zips)
  }

  output {
  File merged_qc = merge_counts.merged_qc
  File multiqc_html = multiqc_local_call.html_report
  Array[File] multiqc_reports = multiqc_local_call.reports
}
}
