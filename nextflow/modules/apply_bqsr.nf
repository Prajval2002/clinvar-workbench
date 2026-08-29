process APPLY_BQSR {

    tag "$sample_id"

    container 'broadinstitute/gatk:4.6.2.0'

    publishDir "${params.output_root}/${sample_id}/bqsr", mode: 'copy'

    cpus 4
    memory '6 GB'

    input:
    tuple val(sample_id), path(bam), path(bai)
    tuple path(reference), path(reference_fai), path(reference_dict)
    path recal_table

    output:
    tuple val(sample_id),
          path("${sample_id}.bqsr.bam"),
          path("${sample_id}.bqsr.bai"),
          emit: bam

    script:
    """
    gatk ApplyBQSR \
        -R ${reference} \
        -I ${bam} \
        --bqsr-recal-file ${recal_table} \
        -O ${sample_id}.bqsr.bam \
        --create-output-bam-index true
    """
}
