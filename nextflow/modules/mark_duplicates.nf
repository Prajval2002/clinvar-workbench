process MARK_DUPLICATES {

    tag "$sample_id"

    container 'broadinstitute/gatk:4.6.2.0'

    publishDir "${params.output_root}/${sample_id}/alignment", mode: 'copy'

    cpus 4
    memory '6 GB'

    input:
    tuple val(sample_id), path(bam)

    output:
    tuple val(sample_id),
          path("${sample_id}.dedup.bam"),
          path("${sample_id}.dedup.bai"),
          path("${sample_id}.dedup.metrics.txt"),
          emit: dedup

    script:
    """
    gatk MarkDuplicates \
        -I ${bam} \
        -O ${sample_id}.dedup.bam \
        -M ${sample_id}.dedup.metrics.txt \
        --CREATE_INDEX true \
        --VALIDATION_STRINGENCY STRICT
    """
}
