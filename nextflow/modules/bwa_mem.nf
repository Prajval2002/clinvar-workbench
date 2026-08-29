process BWA_MEM {

    tag "$sample_id"

    container 'staphb/bwa:0.7.19'

    cpus 6
    memory '8 GB'

    input:
    tuple val(sample_id), path(r1), path(r2)
    tuple path(bwa_index_files), val(bwa_prefix)

    output:
    tuple val(sample_id), path("${sample_id}.sam"), emit: sam

    script:
    """
    bwa mem \
        -t ${task.cpus} \
        -R '@RG\\tID:${sample_id}\\tSM:${sample_id}\\tPL:ILLUMINA' \
        ${bwa_prefix} \
        ${r1} \
        ${r2} \
        > ${sample_id}.sam
    """
}
