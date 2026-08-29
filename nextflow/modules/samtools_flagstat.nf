process SAMTOOLS_FLAGSTAT {

    tag "$sample_id"

    container 'quay.io/biocontainers/samtools:1.22.1--h96c455f_0'

    publishDir "${params.output_root}/${sample_id}/alignment", mode: 'copy'

    cpus 2
    memory '2 GB'

    input:
    tuple val(sample_id), path(bam)

    output:
    tuple val(sample_id), path("${sample_id}.flagstat.txt"), emit: flagstat

    script:
    """
    samtools flagstat \
        -@ ${task.cpus} \
        ${bam} \
        > ${sample_id}.flagstat.txt
    """
}
