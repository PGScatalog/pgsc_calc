//
// This file holds several Groovy functions that could be useful for any Nextflow pipeline
//

import org.yaml.snakeyaml.Yaml
import groovyx.gpars.dataflow.DataflowBroadcast
import java.nio.file.Path

class Utils {

    //
    // When running with -profile conda, warn if channels have not been set-up appropriately
    //
    public static void checkCondaChannels(log) {
        Yaml parser = new Yaml()
        def channels = []
        try {
            def config = parser.load("conda config --show channels".execute().text)
            channels = config.channels
        } catch(NullPointerException | IOException e) {
            log.warn "Could not verify conda channel configuration."
            return
        }

        // Check that all channels are present
        def required_channels = ['conda-forge', 'bioconda', 'defaults']
        def conda_check_failed = !required_channels.every { ch -> ch in channels }

        // Check that they are in the right order
        conda_check_failed |= !(channels.indexOf('conda-forge') < channels.indexOf('bioconda'))
        conda_check_failed |= !(channels.indexOf('bioconda') < channels.indexOf('defaults'))

        if (conda_check_failed) {
            log.warn "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
                "  There is a problem with your Conda configuration!\n\n" +
                "  You will need to set-up the conda-forge and bioconda channels correctly.\n" +
                "  Please refer to https://bioconda.github.io/user/install.html#set-up-channels\n" +
                "  NB: The order of the channels matters!\n" +
                "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        }
    }

    // a convenience function for using nextflow's .combine() with hashmap keys
    // the key must be a list of hashmap keys
    // the hashmap must be at the head of a list
    // the key can be a subset of hashmap keys
    static DataflowBroadcast submapCombine(channel_a, channel_b, keys, flatten=true) {
        channel_a
            .mix(channel_b)
            .map { keys.collect { key -> assert it.first().containsKey(key) } }

        if (flatten) {
            return channel_a.map { it -> [it.first().subMap(keys), it] }
                .combine(channel_b.map { it -> [it.first().subMap(keys), it] }, by: 0)
                .map{ it.tail().flatten() }
        } else {
            return channel_a.map { it -> [it.first().subMap(keys), it] }
                .combine(channel_b.map { it -> [it.first().subMap(keys), it] }, by: 0)
                .map{ it.tail() }
        }
    }

    // extract chromosome from file path
    static List annotateChrom(List channel) {
        def meta = channel.first().clone()
        meta.chrom = channel.last().getBaseName().tokenize('_')[1]
        return [meta, channel.last()]
    }

    // [map, object, ..., map, object]
    // if drop = false, keep maps with matching key, leave objects alone
    // if drop = true, drop maps with matching key, leave objects alone
    static List filterMapListByKey(List channel, String key, boolean drop = false) {
        return channel.findAll {
            if (it instanceof LinkedHashMap) {
                if (drop) {
                    return !it.containsKey(key)
                } else {
                    return it.containsKey(key)
                }
            } else {
                return true
            }
        }
    }

    // grab a long flat tuple with a structure like:
    // [meta, 1_matched.txt.gz, ..., n_matched.txt.gz,
    //     ref_geno, ref_var, ref_pheno, ld, king]
    // and make the intersected match reports (1_matched.txt.gz...) into a list, like:
    // [meta.id, meta.build], list[intersected], ref_geno, ref_var, ref_pheno, ld, king]
    static List listifyMatchReports(List channel) {
        def meta = channel.first()
        def matches = []
        def not_matches = []

        for (item in channel){
            // explicitly importing java.nio.file.Path fixes failed compilation
            if (item instanceof Path) {
                if (item.getName() ==~ '.*matched.txt.gz$') {
                    matches.add(item)
                } else {
                    not_matches.add(item)
                }
            }
        }
        return [meta, matches, *not_matches]
    }

}
