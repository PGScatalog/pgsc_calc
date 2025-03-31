.. _aou:

##############################################################
Running the PGS Catalog Calculator via the All of Us workbench
##############################################################

The examples below assume you are running a Python 3 kernel in a Jupyter notebook on the All of Us workbench.

.. note:: These instructions are a work in progress and are liable to change over time. `pgsc_calc` pipeline is not
    optimized for this cloud environment and data, we are making improvements to the software for this use case.


1. Prepare the genetic data
===========================

Set up the environment
----------------------

Choose a short name for the phenotype (no spaces). This will appear in
the output directory name.

.. code::

    # import required packages
    import os

    # chose a phenotype name (or a unique name to label the results directory)
    os.environ['PHENOTYPE'] = "EXAMPLE"

Set up the dsub function for job submission
-------------------------------------------

.. code::

    %%writefile ~/aou_dsub.bash
    #!/bin/bash

    function aou_dsub () {

      # Get a shorter username to leave more characters for the job name.
      local DSUB_USER_NAME="$(echo "${OWNER_EMAIL}" | cut -d@ -f1)"

      # For AoU RWB projects network name is "network".
      local AOU_NETWORK=network
      local AOU_SUBNETWORK=subnetwork

      dsub \
          --provider google-cls-v2 \
          --user-project "${GOOGLE_PROJECT}"\
          --project "${GOOGLE_PROJECT}"\
          --image 'marketplace.gcr.io/google/ubuntu1804:latest' \
          --network "${AOU_NETWORK}" \
          --subnetwork "${AOU_SUBNETWORK}" \
          --service-account "$(gcloud config get-value account)" \
          --user "${DSUB_USER_NAME}" \
          --regions us-central1 \
          --logging "${WORKSPACE_BUCKET}/dsub/logs/{job-name}/{user-id}/$(date +'%Y%m%d/%H%M%S')/{job-id}.log" \
          "$@"
    }

.. code::

    with open("/home/jupyter/.bashrc", "w") as f:
        f.write("source /home/jupyter/aou_dsub.bash\n")
        f.write("export NXF_OFFLINE='true'")

Create subset of the WGS data
-----------------------------

The All of Us WGS ACAF dataset is too large to be easily used in PGS
calculations. To overcome this, we will first extract a subset of
variants using a custom list containing the most relevant genomic
positions for PGS calculation (``pgsc_all+hm3_variants_hg38_[DATE].txt.gz``,
available from the `resources folder on our FTP`_). This file comprises
merged data representing ~17.9 million genomic positions extracted from
~5,000 PGS Catalog scoring files and the HapMap3+ dataset - the file is updated
regularly and updates are date-stamped.

.. _resources folder on our FTP: https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/

Upload the custom variant list to your workspace bucket
-------------------------------------------------------

You can upload the custom variant file (e.g. ``pgsc_all+hm3_variants_hg38_2024-11-22.txt.gz``) by selecting *File -> Open…* then
clicking *Upload*. Once this has been upload to your workbench, you must
then copy it to your workspace bucket:

.. code::

    !gsutil -u $GOOGLE_PROJECT cp ./pgsc_all+hm3_variants_hg38_2024-11-22.txt ${WORKSPACE_BUCKET}/variant_set/

Copy the WGS files into your workspace bucket
---------------------------------------------

**Important:** Once the WGS data has been successfully subset, you must
remember to delete the original WGS files from your workspace bucket.
This is to reduce the high costs associated with storing these large
files. Code for deleting these files is provided at the end of this
section.

.. code::

    !gsutil -u $GOOGLE_PROJECT -m cp gs://fc-aou-datasets-controlled/v7/wgs/short_read/snpindel/acaf_threshold_v7.1/plink_bed/* $WORKSPACE_BUCKET/acaf/

Set up parameter files for dsub
-------------------------------

File containing the plink2 command to run on each chromosome.

.. code::

    %%writefile subset_variants.sh
    #!/bin/bash

    set -o errexit
    set -o nounset

    plink2 \
          --bfile "${BUCKET}/acaf/acaf_threshold.chr${CHROM}" \
          --extract range "${BUCKET}/variant_set/hm3_pgsc_all_variants_hg38.tsv" \
          --make-pgen vzs \
          --memory 15000 \
          --out "${OUT}/aou_chr_${CHROM}"

File containing the list of chromosomes to include.

.. code::

    START = 1
    END = 22
    INCLUDE_X = True

    all_chromosomes = ["--env CHROM\n"] + [str(n) + "\n" for n in range(START, END + 1)]

    if INCLUDE_X:
        all_chromosomes.append("X")

    with (open("chrom_list.tsv", "w") as file):
        file.writelines(all_chromosomes)

Extract the variant subset
---------------------------

.. code::

    %%bash --out job_ID

    source ~/aou_dsub.bash

    aou_dsub \
      --image biocontainer/plink2:alpha2.3_jan2020 \
      --boot-disk-size 50 \
      --disk-size 256 \
      --min-cores 1 \
      --min-ram 16 \
      --mount BUCKET="${WORKSPACE_BUCKET}" \
      --tasks "chrom_list.tsv" \
      --output-recursive OUT="${WORKSPACE_BUCKET}/acaf_filtered" \
      --logging "${WORKSPACE_BUCKET}/dsub/logs/subset_variants/$(date +'%Y-%m-%d/%H-%M-%S')/subset_variants.log" \
      --script "subset_variants.sh"

Check the status of the job
---------------------------

Get the job identifiers:

.. code::

    # set user name
    USER_NAME = os.getenv('OWNER_EMAIL').split('@')[0].replace('.','-')
    %env USER_NAME={USER_NAME}

    # set job ID
    JOB_ID = job_ID.strip()
    %env JOB_ID={JOB_ID}

Check status of job tasks. **NOTE:** All tasks must have successfully
completed before attempting to run the Calculator (~30 hours).

.. code::

    !dstat \
        --provider google-cls-v2 \
        --project "${GOOGLE_PROJECT}" \
        --location us-central1 \
        --users "${USER_NAME}" \
        --jobs "${JOB_ID}" \
        --status '*'

Delete the original WGS files from your bucket
----------------------------------------------

This is important for reducing storage costs. You must wait until the
variant extraction has successfully completed.

.. code::

    !gsutil -m rm -r ${WORKSPACE_BUCKET}/acaf/

2. Download scoring files
==========================

Install the CLI application for downloading scoring files from the PGS
Catalog:

.. code::

    !pip install pgscatalog-core

Download the scoring files you want to use (harmonised to GRCh38).
Specify scores using either the ``--pgs`` (to download specific PGS
IDs), ``--efo`` (to download all scores associated with a trait) or
``--pgp`` (to download all scores from a particular publication)
options. E.g.

PGS IDs: ``--pgs PGS000822 PGS001229``

Trait ontology terms: ``--efo MONDO_0004975``

Publication IDs: ``--pgp PGP000517``

Update this line in the following code cell with your options
``!pgscatalog-download <YOUR OPTIONS HERE> --build GRCh38 -o scoring_files``

.. code::

    # create new directory to store scoring files (delete previous directory if present)
    !rm -rf scoring_files
    !mkdir scoring_files

    # download scoring files (update with your options)
    !pgscatalog-download --pgs PGS000027 --build GRCh38 -o scoring_files

    # copy scoring files to cloud storage (delete previous directory if present)
    !gsutil -m rm -rf ${WORKSPACE_BUCKET}/scoring_files/
    !gsutil -u $GOOGLE_PROJECT -m cp ./scoring_files/* ${WORKSPACE_BUCKET}/scoring_files/

3. Download the reference dataset (optional)
============================================

*(This step is only required if you want to run the calculator using the
ancestry adjustment)*

.. code::

    # download the data
    !wget https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_HGDP+1kGP_v1.tar.zst

    # move the data to your home directory
    !mv ./pgsc_HGDP+1kGP_v1.tar.zst ~/

Copying the reference data to your workspace bucket takes a while (~2.5
hours). Let’s run this step in the background.

**How to run code in a detached terminal using screen:**

- Open the Cloud Analysis Terminal in a new window (``>_`` icon on
  sidebar)
- Start a new terminal using ``screen -S pgsc_calc``

Run the following command to copy the reference data to your workspace
bucket:

``gsutil -u $GOOGLE_PROJECT -m cp ~/pgsc_HGDP+1kGP_v1.tar.zst ${WORKSPACE_BUCKET}/reference_data/``

**Useful screen commands:** - Create new session:
``screen -S pgsc_calc``\  - Detach session: *Ctrl + A + D*\  - Detach
and delete session: *Ctrl + D*\  - Reattach session:
``screen -r pgsc_calc``\  - List running sessions: ``screen -ls``

4. Calculate polygenic scores
==============================

Create the samplesheet
----------------------

.. code::

    # samplesheet for AoU WGS data (ACAF threshold)

    import json

    BUCKET_DIR = os.environ['WORKSPACE_BUCKET']
    BUCKET_DIR = "/mnt/data/mount/gs/" + BUCKET_DIR.replace("gs://", "")

    # select chromosomes to include
    START = 1
    END = 22
    INCLUDE_X = True

    all_chromosomes = list(range(START, END + 1))

    if INCLUDE_X:
        all_chromosomes.append("X")

    # create a sample sheet entry for each chromosome
    samplesheet = []

    for chrom in all_chromosomes:
        chrom_template = {
            'pheno': BUCKET_DIR + f'/acaf_filtered/aou_chr_{chrom}.psam',
            'vcf_import_dosage': False,
            'variants': BUCKET_DIR + f'/acaf_filtered/aou_chr_{chrom}.pvar.zst',
            'geno': BUCKET_DIR + f'/acaf_filtered/aou_chr_{chrom}.pgen',
            'sampleset': 'aou',
            'chrom': f'{chrom}',
            'format': 'pfile'
        }
        samplesheet.append(chrom_template)

    with open("samplesheet.json", 'w', encoding = 'utf-8') as file:
        json.dump(samplesheet, file, ensure_ascii = False, indent = 4)

    # upload the samplesheet file to your workspace bucket
    !gsutil -u $GOOGLE_PROJECT -m cp ./samplesheet.json ${WORKSPACE_BUCKET}/pgsc_calc_files/

Create the config file
----------------------

.. code::

    config = """
    process {
        withName: 'INTERSECT_THINNED' {
            time = 72.hour
        }
        withName: 'PLINK2_SCORE' {
            time = 48.hour
        }
        withName: 'FRAPOSA_PROJECT' {
            time = 48.hour
        }
    }"""

    with (open("aou.config", "w") as file):
        file.writelines(config)

    # upload the samplesheet file to your workspace bucket
    !gsutil -u $GOOGLE_PROJECT -m cp ./aou.config ${WORKSPACE_BUCKET}/pgsc_calc_files/

Create genotypes cache
----------------------

This will create a new directory to store the processed genotype files.
These files will be reused in subsequent runs to speed up the pipeline
(if you will be using the same genotype files and reference data).

.. code::

    # create new local directory
    !rm -rf genotypes_cache
    !mkdir -p genotypes_cache
    # placeholder file so directory is non-empty
    !touch genotypes_cache/placeholder.txt

    # replace genotype cache in workspace bucket
    !gsutil -m rm -rf ${WORKSPACE_BUCKET}/genotypes_cache/
    !gsutil -u $GOOGLE_PROJECT cp -r ./genotypes_cache ${WORKSPACE_BUCKET}/

.. warning:: Run this code cell only once. Only re-run this code cell if you wish to reset the cache.


Set up the parameter file and run the calculator
------------------------------------------------

**Run 1:** Fresh run of pgsc_calc that re-processes raw data

You should choose this option if you are running the PGS Calculator for
the first time (or have reset the genotypes cache). If you are not using
the ancestry adjustment, remove the ``--run_ancestry`` line from the
first code cell.

Create the parameter file:

.. code::

    %%writefile run_calc.sh
    #!/bin/bash

    set -o errexit
    set -o nounset

    nextflow run /opt/pgsc_calc/main.nf \
          -profile conda \
          --input "${BUCKET}/pgsc_calc_files/samplesheet.json" \
          --format json \
          --target_build GRCh38 \
          --scorefile "${BUCKET}/scoring_files/*" \
          -c "${BUCKET}/pgsc_calc_files/aou.config" \
          --genotypes_cache "${CACHE_IN}" \
          --run_ancestry "${BUCKET}/reference_data/pgsc_HGDP+1kGP_v1.tar.zst" \
          --outdir "${OUT}" \
          --max_cpus 4 \
          --max_memory 208.GB \
          --max_time 240.h \
          --min_overlap 0.5

    cp -r ${CACHE_IN}/* ${CACHE_OUT}

Run the calculator:

.. code::

    %%bash --out job_ID

    source ~/aou_dsub.bash

    aou_dsub \
      --image pgscatalog/pgsc_calc:v2-blob \
      --boot-disk-size 50 \
      --disk-size 512 \
      --min-cores 4 \
      --min-ram 208 \
      --mount BUCKET="${WORKSPACE_BUCKET}" \
      --output-recursive OUT="${WORKSPACE_BUCKET}/calc_results/${PHENOTYPE}" \
      --input-recursive CACHE_IN="${WORKSPACE_BUCKET}/genotypes_cache" \
      --output-recursive CACHE_OUT="${WORKSPACE_BUCKET}/genotypes_cache" \
      --logging "${WORKSPACE_BUCKET}/dsub/logs/pgsc_calc/$(date +'%Y-%m-%d/%H-%M-%S')/pgsc_calc.log" \
      --script "run_calc.sh"

**All other runs:** Subsequent runs use cached genotypes to speed up calculation

You should choose this option if you have already run the PGS Calculator
previously and the processed genotype files are still stored in the
genotypes cache. If you are not using the ancestry adjustment, remove
the ``--run_ancestry`` line from the first code cell.

Create the parameter file:

.. code::

    %%writefile run_calc2.sh
    #!/bin/bash

    set -o errexit
    set -o nounset

    nextflow run /opt/pgsc_calc/main.nf \
          -profile conda \
          --input "${BUCKET}/pgsc_calc_files/samplesheet.json" \
          --format json \
          --target_build GRCh38 \
          --scorefile "${BUCKET}/scoring_files/*" \
          --genotypes_cache "${BUCKET}/genotypes_cache" \
          --run_ancestry "${BUCKET}/reference_data/pgsc_HGDP+1kGP_v1.tar.zst" \
          --outdir "${OUT}" \
          --max_cpus 4 \
          --max_memory 208.GB \
          --max_time 240.h \
          --min_overlap 0.5

Run the calculator:

.. code::

    %%bash --out job_ID

    source ~/aou_dsub.bash

    aou_dsub \
      --image pgscatalog/pgsc_calc:v2-blob \
      --boot-disk-size 50 \
      --disk-size 512 \
      --min-cores 4 \
      --min-ram 208 \
      --mount BUCKET="${WORKSPACE_BUCKET}" \
      --output-recursive OUT="${WORKSPACE_BUCKET}/calc_results/${PHENOTYPE}" \
      --logging "${WORKSPACE_BUCKET}/dsub/logs/pgsc_calc/$(date +'%Y-%m-%d/%H-%M-%S')/pgsc_calc.log" \
      --script "run_calc2.sh"

Check the status of the job
---------------------------

Get the job identifiers:

.. code::

    # set user name
    USER_NAME = os.getenv('OWNER_EMAIL').split('@')[0].replace('.','-')
    %env USER_NAME={USER_NAME}

    # set job ID
    JOB_ID = job_ID.strip()
    %env JOB_ID={JOB_ID}

Check status of job:

.. code::

    !dstat \
        --provider google-cls-v2 \
        --project "${GOOGLE_PROJECT}" \
        --location us-central1 \
        --users "${USER_NAME}" \
        --jobs "${JOB_ID}" \
        --status '*'

Copy the calculator results to your workbench
---------------------------------------------

Once the calculator has successfully completed, the results directory
will be available in your workspace bucket. However, you may prefer to
have a local copy on your researcher workbench to use in subsequent
analyses:

.. code::

    !mkdir -p calc_results
    !gsutil -u $GOOGLE_PROJECT -m cp -r "${WORKSPACE_BUCKET}/calc_results/${PHENOTYPE}_test" ./calc_results/

Citation & credits
==================

If you use the PGS Catalog Calculator in your work, please cite our most
recent publication:

   Lambert, S.A., Wingfield, B., Gibson, J.T. *et al*. Enhancing the
   Polygenic Score Catalog with tools for score calculation and ancestry
   normalization. *Nat Genet* 56, 1989–1994 (2024).
   https://doi.org/10.1038/s41588-024-01937-x

Thanks to Sarah Abramowitz, Michael Levin, and colleagues at UPenn for sharing their code for running `pgsc_calc`
in the AoU TRE which informed these instructions.

Extra code
==========

Displaying a text file stored in your workspace bucket:

.. code::

    !gsutil -u $GOOGLE_PROJECT cat "PATH TO FILE. E.g. gs://fc-secure..."

Copying a file from your workspace bucket to your persistent disk:

.. code::

    !gsutil -u $GOOGLE_PROJECT cp "PATH TO FILE. E.g. gs://fc-secure..." ./
