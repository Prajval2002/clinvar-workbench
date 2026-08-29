process VARIANT_FILTER {

    tag "$sample_id"

    container 'broadinstitute/gatk:4.6.2.0'

    publishDir "${params.output_root}/${sample_id}/variants", mode: 'copy'

    cpus 2
    memory '4 GB'

    input:
    tuple val(sample_id), path(vcf), path(vcf_tbi)

    output:
    tuple val(sample_id),
          path("${sample_id}.filtered.vcf.gz"),
          path("${sample_id}.filtered.vcf.gz.tbi"),
          emit: vcf

    script:
    """
    gatk VariantFiltration \
        -V ${vcf} \
        -O ${sample_id}.filtered.vcf.gz \
        --filter-name "QD_lt_2" \
        --filter-expression "QD < 2.0" \
        --filter-name "FS_gt_60" \
        --filter-expression "FS > 60.0" \
        --filter-name "SOR_gt_3" \
        --filter-expression "SOR > 3.0" \
        --filter-name "MQ_lt_40" \
        --filter-expression "MQ < 40.0" \
        --filter-name "MQRankSum_lt_neg12_5" \
        --filter-expression "MQRankSum < -12.5" \
        --filter-name "ReadPosRankSum_lt_neg8" \
        --filter-expression "ReadPosRankSum < -8.0" \
        --create-output-variant-index true
    """
}
