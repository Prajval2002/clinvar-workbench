process MULTIQC {

    tag "$sample_id"

    container 'quay.io/biocontainers/multiqc:1.29--pyhdfd78af_0'

    input:
    tuple val(sample_id), path(qc_files)

    output:
    tuple val(sample_id), path("multiqc_report.html"), emit: html
    tuple val(sample_id), path("multiqc_report_data"), emit: data

    script:
    """
    multiqc \
        --force \
        --outdir . \
        --filename multiqc_report.html \
        .
    """
}
