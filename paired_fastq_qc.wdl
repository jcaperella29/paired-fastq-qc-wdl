version 1.0

struct FastqPair {
  String sample_id
  File r1
  File r2
}

task validate_one_pair_id {
  input {
    FastqPair pair
  }

  command <<<
    set -euo pipefail
    echo "~{pair.sample_id}" > sample_id.txt
  >>>

  output {
    File sample_id_file = "sample_id.txt"
  }

  runtime {
    cpu: 1
    memory: "256M"
    docker: "ubuntu:22.04"
  }
}

task check_unique_sample_ids {
  input {
    Array[File] sample_id_files
  }

  command <<<
    set -euo pipefail

    cat ~{sep=' ' sample_id_files} > all_sample_ids.txt

    dup=$(sort all_sample_ids.txt | uniq -d || true)
    if [ -n "$dup" ]; then
      echo "ERROR: Duplicate sample_id(s):" >&2
      echo "$dup" >&2
      exit 3
    fi

    echo "OK: sample_id uniqueness passed."
  >>>

  output {
    File all_sample_ids = "all_sample_ids.txt"
  }

  runtime {
    cpu: 1
    memory: "512M"
    docker: "ubuntu:22.04"
  }
}

task manifest_row {
  input {
    FastqPair pair
  }

  command <<<
    set -euo pipefail

    b1=$(stat -c%s "~{pair.r1}")
    b2=$(stat -c%s "~{pair.r2}")

    echo -e "~{pair.sample_id}\t~{pair.r1}\t${b1}\t~{pair.r2}\t${b2}" > row.tsv
  >>>

  output {
    File row = "row.tsv"
  }

  runtime {
    cpu: 1
    memory: "256M"
    docker: "ubuntu:22.04"
  }
}

task merge_manifest {
  input {
    Array[File] rows
  }

  command <<<
    set -euo pipefail

    echo -e "sample_id\tr1\tbytes_r1\tr2\tbytes_r2" > manifest.tsv
    cat ~{sep=' ' rows} | sort -k1,1 >> manifest.tsv
  >>>

  output {
    File manifest = "manifest.tsv"
  }

  runtime {
    cpu: 1
    memory: "512M"
    docker: "ubuntu:22.04"
  }
}

task pair_qc {
  input {
    FastqPair pair
    Int cpu_fastqc = 1
    String mem_fastqc = "2G"
  }

  command <<<
    set -euo pipefail

    count_reads () {
      f="$1"
      if [[ "$f" == *.gz ]]; then
        l=$(zcat "$f" | wc -l)
      else
        l=$(wc -l < "$f")
      fi
      echo $((l / 4))
    }

    check_fastq () {
      f="$1"
      if [[ "$f" == *.gz ]]; then
        l=$(zcat "$f" | wc -l)
      else
        l=$(wc -l < "$f")
      fi
      if (( l % 4 != 0 )); then
        echo "ERROR: $f has $l lines (not divisible by 4)" >&2
        exit 2
      fi
    }

    check_fastq "~{pair.r1}"
    check_fastq "~{pair.r2}"

    r1_reads=$(count_reads "~{pair.r1}")
    r2_reads=$(count_reads "~{pair.r2}")

    out_counts="counts_~{pair.sample_id}.tsv"
    echo -e "sample_id\tr1_reads\tr2_reads" > "$out_counts"
    echo -e "~{pair.sample_id}\t${r1_reads}\t${r2_reads}" >> "$out_counts"

    mkdir -p fastqc_out
    fastqc -q -o fastqc_out "~{pair.r1}" "~{pair.r2}"

    ls -lah fastqc_out
  >>>

  output {
    File counts_tsv = "counts_~{pair.sample_id}.tsv"
    Array[File] fastqc_zips = glob("fastqc_out/*_fastqc.zip")
    Array[File] fastqc_htmls = glob("fastqc_out/*_fastqc.html")
  }

  runtime {
    cpu: cpu_fastqc
    memory: mem_fastqc
    docker: "quay.io/biocontainers/fastqc:0.11.9--0"
  }
}

task merge_counts {
  input {
    Array[File] counts
  }

  command <<<
    set -euo pipefail

    if [ ~{length(counts)} -eq 0 ]; then
      echo "ERROR: counts array empty." >&2
      exit 1
    fi

    head -n 1 "~{counts[0]}" > merged_qc.tsv
    for f in ~{sep=' ' counts}; do
      tail -n +2 "$f" >> merged_qc.tsv
    done

    {
      head -n 1 merged_qc.tsv
      tail -n +2 merged_qc.tsv | sort -k1,1
    } > merged_qc.sorted.tsv

    mv merged_qc.sorted.tsv merged_qc.tsv
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
    Int cpu_multiqc = 1
    String mem_multiqc = "2G"
  }

  command <<<
    set -euo pipefail

    mkdir -p fastqc_inputs multiqc_out

    if [ ~{length(fastqc_zips)} -eq 0 ]; then
      echo "ERROR: fastqc_zips is empty." >&2
      exit 1
    fi

    for z in ~{sep=" " fastqc_zips}; do
      ln -sf "$z" fastqc_inputs/
    done

    multiqc -q -o multiqc_out fastqc_inputs
  >>>

  output {
    File html_report = "multiqc_out/multiqc_report.html"
    Array[File] reports = glob("multiqc_out/*")
  }

  runtime {
    cpu: cpu_multiqc
    memory: mem_multiqc
    docker: "quay.io/biocontainers/multiqc:1.14--pyhdfd78af_0"
  }
}

workflow paired_fastq_qc_workflow {
  input {
    Array[FastqPair] pairs
    Int fastqc_cpu = 1
    String fastqc_mem = "2G"
    Int multiqc_cpu = 1
    String multiqc_mem = "2G"
  }

  scatter (p in pairs) {
    call validate_one_pair_id { input: pair = p }
    call manifest_row { input: pair = p }
    call pair_qc {
      input:
        pair = p,
        cpu_fastqc = fastqc_cpu,
        mem_fastqc = fastqc_mem
    }
  }

  call check_unique_sample_ids {
    input: sample_id_files = validate_one_pair_id.sample_id_file
  }

  call merge_manifest {
    input: rows = manifest_row.row
  }

  call merge_counts {
    input: counts = pair_qc.counts_tsv
  }

  call multiqc_local as multiqc_local_call {
    input:
      fastqc_zips = flatten(pair_qc.fastqc_zips),
      cpu_multiqc = multiqc_cpu,
      mem_multiqc = multiqc_mem
  }

  output {
    File merged_qc = merge_counts.merged_qc
    File multiqc_html = multiqc_local_call.html_report
    Array[File] multiqc_reports = multiqc_local_call.reports
    File manifest = merge_manifest.manifest
    File all_sample_ids = check_unique_sample_ids.all_sample_ids
  }
}
