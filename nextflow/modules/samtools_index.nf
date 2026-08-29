process SAMTOOLS_INDEX {

    tag "$sample_id"

    container 'quay.io/biocontainers/samtools:1.22.1--h96c455f_0'

    publishDir "${params.output_root}/${sample_id}/alignment", mode: 'copy'

    cpus 2
    memory '4 GB'

    input:
    tuple val(sample_id), path(bam)

    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam.bai"), emit: bai

    script:
    """
    samtools index \
        -@ ${task.cpus} \
        ${bam}
    """
}
