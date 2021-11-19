//
// This file holds several functions specific to the workflow/pgscalc.nf in the nf-core/pgscalc pipeline
//

class WorkflowPgscalc {
    //
    // Check and validate parameters
    //
    public static void initialise(params, log) {
        if (!params.input) {
            log.error "Sample sheet input file not specified with e.g. '--input input.csv' or via a detectable config file."
            System.exit(1)
        }
    }
}
