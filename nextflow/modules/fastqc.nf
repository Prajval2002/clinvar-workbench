process FASTQC {

    tag "$sample_id"

    container 'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0'

    input:
    tuple val(sample_id), path(r1), path(r2)

    output:
    tuple val(sample_id), path("*_fastqc.html"), emit: html
    tuple val(sample_id), path("*_fastqc.zip"), emit: zip

    script:
    """
    fastqc \
        --threads 2 \
        --outdir . \
        ${r1} \
        ${r2}
    """
}
