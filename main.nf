nextflow.enable.dsl=2

include { QC } from './nextflow/subworkflows/qc'

params.data_root = "${launchDir}/data"

workflow {

    data_root = file(params.data_root, checkIfExists: true)

    samplesheet = file("${data_root}/samplesheet.csv", checkIfExists: true)

    /*
     * The samplesheet contains:
     *
     * sample_id,r1,r2
     *
     * Paths in the samplesheet are interpreted relative to the
     * project data root.
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
                        file("${data_root}/${fields[1].trim()}"),
                        file("${data_root}/${fields[2].trim()}")
                    )
                }
        )

    QC(samples)
}
