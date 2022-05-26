How to set parameters in a file
===============================

It can be useful to store workflow parameters in a file if you're running
complex jobs or you want to keep track of exactly what type of analysis you did.

Make YAML file
--------------

Parameters can be stored in YAML format, for example:

.. code-block:: yaml

   input: path/to/samplesheet.csv
   accession: 'PGS001229,PGS000018'
   liftover: true   
   target_build: GRCh37


Save this file as ``my_example_params.yaml``. An `example template`_ used in
pgsc_calc's test suite is also available (see :ref:`testing` for an explanation
of the test suite).

.. _`example template`:  https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/params.yaml

Run pgsc_calc with YAML file
----------------------------

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc \
        -profile <conda/docker/singularity> \
        -params-file my_example_params.yaml

The workflow will now run with the parameters you set up in YAML. See 
:ref:`param ref` for a full description of parameters you can set. 

.. note:: If you prefer JSON, you can `convert the YAML to JSON`_ and it should work
          fine

.. _`convert the YAML to JSON`: https://jsonformatter.org/yaml-to-json    
