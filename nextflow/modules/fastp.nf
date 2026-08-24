process FASTP {

    tag "$sample_id"

    container 'quay.io/biocontainers/fastp:0.23.4--hadf994f_3'

    input:
    tuple val(sample_id), path(r1), path(r2)

    output:
    tuple val(sample_id), path("${sample_id}_R1.trimmed.fastq.gz"), path("${sample_id}_R2.trimmed.fastq.gz"), emit: reads
    tuple val(sample_id), path("${sample_id}_fastp.html"), emit: html
    tuple val(sample_id), path("${sample_id}_fastp.json"), emit: json

    script:
    """
    fastp \
        --in1 ${r1} \
        --in2 ${r2} \
        --out1 ${sample_id}_R1.trimmed.fastq.gz \
        --out2 ${sample_id}_R2.trimmed.fastq.gz \
        --html ${sample_id}_fastp.html \
        --json ${sample_id}_fastp.json \
        --thread 2
    """
}
