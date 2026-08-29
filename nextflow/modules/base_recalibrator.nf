process BASE_RECALIBRATOR {

    tag "$sample_id"

    container 'broadinstitute/gatk:4.6.2.0'

    publishDir "${params.output_root}/${sample_id}/bqsr", mode: 'copy'

    cpus 4
    memory '6 GB'

    input:
    tuple val(sample_id), path(bam), path(bai)
    tuple path(reference), path(reference_fai), path(reference_dict)
    tuple path(known_sites_vcf), path(known_sites_tbi)

    output:
    tuple val(sample_id), path("${sample_id}.recal_data.table"), emit: table

    script:
    """
    gatk BaseRecalibrator \
        -R ${reference} \
        -I ${bam} \
        --known-sites ${known_sites_vcf} \
        -O ${sample_id}.recal_data.table
    """
}
