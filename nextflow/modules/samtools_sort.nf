process SAMTOOLS_SORT {

    tag "$sample_id"

    container 'quay.io/biocontainers/samtools:1.22.1--h96c455f_0'

    publishDir "${params.output_root}/${sample_id}/alignment", mode: 'copy'

    cpus 4
    memory '8 GB'

    input:
    tuple val(sample_id), path(sam)

    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam"), emit: bam

    script:
    """
    samtools sort \
        -@ ${task.cpus} \
        -m 1G \
        -T ${sample_id}.sorttmp \
        -o ${sample_id}.sorted.bam \
        ${sam}

    samtools quickcheck ${sample_id}.sorted.bam

    rm -f ${sam}
    """
}
