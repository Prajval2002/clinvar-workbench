include { BWA_MEM } from '../modules/bwa_mem'
include { SAMTOOLS_SORT } from '../modules/samtools_sort'
include { SAMTOOLS_INDEX } from '../modules/samtools_index'
include { SAMTOOLS_FLAGSTAT } from '../modules/samtools_flagstat'
include { SAMTOOLS_STATS } from '../modules/samtools_stats'
include { MARK_DUPLICATES } from '../modules/mark_duplicates'
include { BASE_RECALIBRATOR } from '../modules/base_recalibrator'
include { APPLY_BQSR } from '../modules/apply_bqsr'

workflow ALIGNMENT {

    take:
    reads
    bwa_index
    reference_bundle
    known_sites

    main:

    BWA_MEM(
        reads,
        bwa_index
    )

    SAMTOOLS_SORT(
        BWA_MEM.out.sam
    )

    SAMTOOLS_INDEX(
        SAMTOOLS_SORT.out.bam
    )

    SAMTOOLS_FLAGSTAT(
        SAMTOOLS_SORT.out.bam
    )

    SAMTOOLS_STATS(
        SAMTOOLS_SORT.out.bam
    )

    MARK_DUPLICATES(
        SAMTOOLS_SORT.out.bam
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
        BASE_RECALIBRATOR.out.table.map { sample_id, table -> table }
    )

    emit:
    bam = SAMTOOLS_SORT.out.bam
    bai = SAMTOOLS_INDEX.out.bai
    flagstat = SAMTOOLS_FLAGSTAT.out.flagstat
    stats = SAMTOOLS_STATS.out.stats

    dedup_bam = MARK_DUPLICATES.out.dedup.map {
        sample_id, bam, bai, metrics ->
        tuple(sample_id, bam)
    }

    dedup_bai = MARK_DUPLICATES.out.dedup.map {
        sample_id, bam, bai, metrics ->
        tuple(sample_id, bai)
    }

    dedup_metrics = MARK_DUPLICATES.out.dedup.map {
        sample_id, bam, bai, metrics ->
        tuple(sample_id, metrics)
    }

    bqsr_bam = APPLY_BQSR.out.bam
}
