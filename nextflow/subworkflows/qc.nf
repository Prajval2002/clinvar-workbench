include { FASTQC as FASTQC_PRE } from '../modules/fastqc'
include { FASTP } from '../modules/fastp'
include { FASTQC as FASTQC_POST } from '../modules/fastqc'
include { MULTIQC } from '../modules/multiqc'

workflow QC {

    take:
    reads

    main:

    // Raw-read quality assessment
    FASTQC_PRE(reads)

    // Adapter and quality trimming
    FASTP(reads)

    // Post-trimming quality assessment
    FASTQC_POST(FASTP.out.reads)

    /*
     * FASTQC emits wildcard outputs as a list of files.
     * Flatten those lists so each QC file becomes an individual
     * (sample_id, file) tuple before aggregation.
     */

    pre_qc_files = FASTQC_PRE.out.html
        .mix(FASTQC_PRE.out.zip)
        .flatMap { sample_id, files ->
            files.collect { file ->
                tuple(sample_id, file)
            }
        }

    fastp_files = FASTP.out.html
        .mix(FASTP.out.json)
        .map { sample_id, file ->
            tuple(sample_id, file)
        }

    post_qc_files = FASTQC_POST.out.html
        .mix(FASTQC_POST.out.zip)
        .flatMap { sample_id, files ->
            files.collect { file ->
                tuple(sample_id, file)
            }
        }

    /*
     * Combine all QC files belonging to the same sample.
     * Result:
     *
     * sample_id,
     * [file1, file2, file3, ...]
     */
    qc_files = pre_qc_files
        .mix(fastp_files)
        .mix(post_qc_files)
        .groupTuple()

    MULTIQC(qc_files)

    emit:
    pre_qc_html  = FASTQC_PRE.out.html
    pre_qc_zip   = FASTQC_PRE.out.zip

    trimmed_reads = FASTP.out.reads
    fastp_html    = FASTP.out.html
    fastp_json    = FASTP.out.json

    post_qc_html = FASTQC_POST.out.html
    post_qc_zip  = FASTQC_POST.out.zip

    multiqc_html = MULTIQC.out.html
    multiqc_data = MULTIQC.out.data
}
