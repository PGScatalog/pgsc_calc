//
// This file holds several functions specific to the workflow/pgscalc.nf in the nf-core/pgscalc pipeline
//

class WorkflowPgscalc {
    //
    // Check and validate parameters
    //
    public static void initialise(params, log) {
        // TODO: decide how to provide / validate reference gnomes
        // genomeExistsError(params, log)

        if (!params.input) {
            log.error "Sample sheet input file not specified with e.g. '--input input.csv' or via a detectable config file."
            System.exit(1)
        }
    }

    //
    // Exit pipeline if incorrect --genome key provided
    //
    private static void genomeExistsError(params, log) {
        if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
            log.error "=============================================================================\n" +
                "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" +
                "  Currently, the available genome keys are:\n" +
                "  ${params.genomes.keySet().join(", ")}\n" +
                "==================================================================================="
            System.exit(1)
        }
    }
}
