include { HAPLOTYPE_CALLER } from '../modules/haplotype_caller'
include { GENOTYPE_GVCFS } from '../modules/genotype_gvcfs'
include { VARIANT_FILTER } from '../modules/variant_filter'

workflow VARIANT_CALLING {

    take:
    bqsr_bam
    reference_bundle
    intervals

    main:

    HAPLOTYPE_CALLER(
        bqsr_bam,
        reference_bundle,
        intervals
    )

    GENOTYPE_GVCFS(
        HAPLOTYPE_CALLER.out.gvcf,
        reference_bundle
    )

    VARIANT_FILTER(
        GENOTYPE_GVCFS.out.vcf
    )

    emit:
    gvcf = HAPLOTYPE_CALLER.out.gvcf
    raw_vcf = GENOTYPE_GVCFS.out.vcf
    filtered_vcf = VARIANT_FILTER.out.vcf
}
