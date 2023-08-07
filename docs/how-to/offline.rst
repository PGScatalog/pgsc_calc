.. _offline:

How do I run pgsc_calc in an offline environment?
=================================================

pgsc_calc has been deployed on secure platforms like Trusted Research
Environments (TREs). Running pgsc_calc is a little bit more difficult in this
case. The basic set up approach is to:

1. Download containers 
2. Download reference data
3. Download scoring files 

And transfer everything to your offline environment.  

This guide assumes you've set up pgsc_calc and tested it in an online
environment first.

Every computing environment has different quirks and it can be difficult to get
everything working correctly. Please feel free to `open a discussion on Github`_
if you are having problems and we'll try our best to help you.

.. _open a discussion on Github: https://github.com/PGScatalog/pgsc_calc/discussions

Preload container images
------------------------

Docker
~~~~~~

Pull and save the docker images to local tar files in an online environment:

.. code-block:: bash

   $ cd /path/to/pgsc_calc
   $ git grep 'ext.docker*' conf/modules.config | cut -f 2 -d '=' | xargs -L 2 echo | tr -d ' ' > images.txt
   $ cat images.txt | xargs -I {} sh -c 'docker pull --platform linux/amd64 "$1"' - {}
   $ mkdir -p docker/
   $ cat images.txt | xargs -I {} sh -c 'docker save "$1" > docker/$(basename "$1").tar' - {}

Tar files will have been saved to the ``docker/`` directory. Transfer this
directory and load the container tars in the offline environment:

.. code-block:: bash
                
   $ find docker -name '*.tar'
   $ find docker/ -name '*.tar' -exec sh -c 'docker load < {}' \;
                
Singularity
~~~~~~~~~~~

Set ``NXF_SINGULARITY_CACHEDIR`` to the directory you want containers to
download to:

.. code-block:: bash
   
  $ cd /path/to/pgsc_calc
  $ export NXF_SINGULARITY_CACHEDIR=path/to/containers

Then pull the images to the directory:  
                
.. code-block:: bash

  $ mkdir -p $NXF_SINGULARITY_CACHEDIR
  $ git grep 'ext.singularity*' conf/modules.config | cut -f 2 -d '=' | xargs -L 2 echo | tr -d ' ' > singularity_images.txt
  $ cat singularity_images.txt | sed 's/oras:\/\///;s/https:\/\///;s/\//-/g;s/$/.img/;s/:/-/' > singularity_image_paths.txt
  $ paste -d '\n'singularity_image_paths.txt singularity_images.txt | xargs -L 2 sh -c 'singularity pull --disable-cache --dir $NXF_SINGULARITY_CACHEDIR $0 $1'
                
And transfer the directory to your offline environment.

.. warning:: Remember to set ``NXF_SINGULARITY_CACHEDIR`` to the directory that
             contains the downloaded containers on your offline system whenever
             you run pgsc_calc, e.g.:

             .. code-block:: bash

               $ export NXF_SINGULARITY_CACHEDIR=path/to/containers
               $ nextflow run main.nf -profile singularity ...

Download reference data
-----------------------

Some small reference data is needed to run the calculator:

* --hg19_chain https://hgdownload.cse.ucsc.edu/goldenpath/hg19/liftOver/hg19ToHg38.over.chain.gz
* --hg38_chain https://hgdownload.soe.ucsc.edu/goldenPath/hg38/liftOver/hg38ToHg19.over.chain.gz

To do ancestry-based score normalisation you'll need to download the reference
panel too. See :ref:`norm`.
             
Download scoring files
----------------------

It's best to manually download scoring files from the PGS Catalog in the correct
genome build. Using PGS001229 as an example:

https://ftp.ebi.ac.uk/pub/databases/spot/pgs/scores/PGS001229/ScoringFiles/

.. code-block:: bash

  $ PGS001229/ScoringFiles
    ├── Harmonized
    │   ├── PGS001229_hmPOS_GRCh37.txt.gz <-- the file you want
    │   ├── PGS001229_hmPOS_GRCh37.txt.gz.md5
    │   ├── PGS001229_hmPOS_GRCh38.txt.gz <-- or perhaps this one!
    │   └── PGS001229_hmPOS_GRCh38.txt.gz.md5
    ├── PGS001229.txt.gz
    ├── PGS001229.txt.gz.md5
    └── archived_versions

These files can be transferred to the offline environment and provided to the
workflow using the ``--scorefile`` parameter.

.. tip:: If you're using multiple scoring files you must use quotes
         e.g. ``--scorefile "path/to/scorefiles/PGS*.txt.gz"``

