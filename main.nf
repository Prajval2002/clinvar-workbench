nextflow.enable.dsl=2

include { QC } from './nextflow/subworkflows/qc'
include { ALIGNMENT } from './nextflow/subworkflows/alignment'
include { VARIANT_CALLING } from './nextflow/subworkflows/variant_calling'
include { VARIANT_SLICE } from './nextflow/subworkflows/variant_slice'

params.data_root = "${launchDir}/data"
params.samplesheet = null
params.output_root = "${params.data_root}/results"
params.reference_root = null
params.intervals = null

params.dev_bam = null
params.dev_sample_id = "HG002_dev_chr1"

workflow {

    /*
     * ------------------------------------------------------------
     * Required reference
     * ------------------------------------------------------------
     */

    if (!params.reference_root) {
        error "Missing --reference_root"
    }

    reference_root = file(
        params.reference_root,
        checkIfExists: true
    )

    /*
     * ------------------------------------------------------------
     * Required output directory
     * ------------------------------------------------------------
     */

    output_root = file(params.output_root)

    /*
     * ------------------------------------------------------------
     * Required HaplotypeCaller interval
     * ------------------------------------------------------------
     */

    if (!params.intervals) {
        error "Missing --intervals"
    }

    intervals = file(
        params.intervals,
        checkIfExists: true
    )

    /*
     * ------------------------------------------------------------
     * Reference bundle
     * ------------------------------------------------------------
     */

    reference_bundle = Channel.value(
        tuple(
            file(
                "${reference_root}/GRCh38.primary_assembly.genome.fa",
                checkIfExists: true
            ),
            file(
                "${reference_root}/GRCh38.primary_assembly.genome.fa.fai",
                checkIfExists: true
            ),
            file(
                "${reference_root}/GRCh38.primary_assembly.genome.dict",
                checkIfExists: true
            )
        )
    )

    /*
     * ------------------------------------------------------------
     * BWA index
     * ------------------------------------------------------------
     */

    bwa_index_files = file(
        "${reference_root}/bwa/GRCh38.*",
        checkIfExists: true
    )

    bwa_index = Channel.value(
        tuple(
            bwa_index_files,
            'GRCh38'
        )
    )

    /*
     * ------------------------------------------------------------
     * dbSNP known sites
     * ------------------------------------------------------------
     */

    known_sites = Channel.value(
        tuple(
            file(
                "${reference_root}/known_sites/primary/dbsnp138.primary.vcf.gz",
                checkIfExists: true
            ),
            file(
                "${reference_root}/known_sites/primary/dbsnp138.primary.vcf.gz.tbi",
                checkIfExists: true
            )
        )
    )

    /*
     * ============================================================
     * DEVELOPMENT-SLICE MODE
     * ============================================================
     *
     * Example:
     *
     * --dev_bam /path/to/chr1_dev200kb.bam
     *
     * This mode skips:
     *
     * FASTQ
     * FastQC
     * fastp
     * BWA-MEM
     * samtools sort
     *
     * and starts from an already aligned BAM.
     */

    if (params.dev_bam) {

        /*
         * Do not allow FASTQ mode simultaneously.
         */
        if (params.samplesheet) {
            error "Use either --dev_bam OR --samplesheet, not both"
        }

        dev_bam = Channel.value(
            tuple(
                params.dev_sample_id,
                file(
                    params.dev_bam,
                    checkIfExists: true
                )
            )
        )

        VARIANT_SLICE(
            dev_bam,
            reference_bundle,
            known_sites,
            intervals
        )

    /*
     * ============================================================
     * NORMAL FASTQ MODE
     * ============================================================
     */

    } else {

        if (!params.samplesheet) {
            error "Missing --samplesheet. Provide --samplesheet for FASTQ mode or --dev_bam for development-slice mode."
        }

        data_root = file(
            params.data_root,
            checkIfExists: true
        )

        samplesheet = file(
            params.samplesheet,
            checkIfExists: true
        )

        /*
         * samplesheet:
         *
         * sample_id,r1,r2
         *
         * Paths are interpreted relative to data_root.
         */

        samples = Channel
            .fromList(
                samplesheet
                    .readLines()
                    .drop(1)
                    .findAll { it.trim() }
                    .collect { line ->

                        def fields = line.split(',', -1)

                        if (fields.size() != 3) {
                            error "Invalid samplesheet line: ${line}"
                        }

                        tuple(
                            fields[0].trim(),
                            file(
                                "${data_root}/${fields[1].trim()}"
                            ),
                            file(
                                "${data_root}/${fields[2].trim()}"
                            )
                        )
                    }
            )

        QC(samples)

        ALIGNMENT(
            QC.out.trimmed_reads,
            bwa_index,
            reference_bundle,
            known_sites
        )

        VARIANT_CALLING(
            ALIGNMENT.out.bqsr_bam,
            reference_bundle,
            intervals
        )
    }
}
