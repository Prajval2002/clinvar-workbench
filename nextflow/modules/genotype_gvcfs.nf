process GENOTYPE_GVCFS {

    tag "$sample_id"

    container 'broadinstitute/gatk:4.6.2.0'

    publishDir "${params.output_root}/${sample_id}/variants", mode: 'copy'

    cpus 4
    memory '8 GB'

    input:
    tuple val(sample_id), path(gvcf), path(gvcf_tbi)
    tuple path(reference), path(reference_fai), path(reference_dict)

    output:
    tuple val(sample_id),
          path("${sample_id}.raw.vcf.gz"),
          path("${sample_id}.raw.vcf.gz.tbi"),
          emit: vcf

    script:
    """
    gatk GenotypeGVCFs \
        -R ${reference} \
        -V ${gvcf} \
        -O ${sample_id}.raw.vcf.gz
    """
}
