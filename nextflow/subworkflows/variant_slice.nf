include { MARK_DUPLICATES } from '../modules/mark_duplicates'
include { BASE_RECALIBRATOR } from '../modules/base_recalibrator'
include { APPLY_BQSR } from '../modules/apply_bqsr'
include { HAPLOTYPE_CALLER } from '../modules/haplotype_caller'
include { GENOTYPE_GVCFS } from '../modules/genotype_gvcfs'
include { VARIANT_FILTER } from '../modules/variant_filter'

workflow VARIANT_SLICE {

    take:
    slice_bam
    reference_bundle
    known_sites
    intervals

    main:

    MARK_DUPLICATES(
        slice_bam
    )

    dedup_input = MARK_DUPLICATES.out.dedup.map {
        sample_id, bam, bai, metrics ->
        tuple(sample_id, bam, bai)
    }

    BASE_RECALIBRATOR(
        dedup_input,
        reference_bundle,
        known_sites
    )

    APPLY_BQSR(
        dedup_input,
        reference_bundle,
        BASE_RECALIBRATOR.out.table.map {
            sample_id, table ->
            table
        }
    )

    HAPLOTYPE_CALLER(
        APPLY_BQSR.out.bam,
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
    dedup = MARK_DUPLICATES.out.dedup
    bqsr = APPLY_BQSR.out.bam
    gvcf = HAPLOTYPE_CALLER.out.gvcf
    raw_vcf = GENOTYPE_GVCFS.out.vcf
    filtered_vcf = VARIANT_FILTER.out.vcf
}
