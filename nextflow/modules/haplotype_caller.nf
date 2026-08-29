process HAPLOTYPE_CALLER {

    tag "$sample_id"

    container 'broadinstitute/gatk:4.6.2.0'

    publishDir "${params.output_root}/${sample_id}/variants", mode: 'copy'

    cpus 4
    memory '8 GB'

    input:
    tuple val(sample_id), path(bam), path(bai)
    tuple path(reference), path(reference_fai), path(reference_dict)
    path intervals

    output:
    tuple val(sample_id),
          path("${sample_id}.g.vcf.gz"),
          path("${sample_id}.g.vcf.gz.tbi"),
          emit: gvcf

    script:
    """
    gatk HaplotypeCaller \
        -R ${reference} \
        -I ${bam} \
        -L ${intervals} \
        -O ${sample_id}.g.vcf.gz \
        -ERC GVCF
    """
}
