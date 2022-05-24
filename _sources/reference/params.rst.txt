.. _param ref:

Parameter reference
===================

The documentation below is automatically generated from the input schema and
contains additional technical detail.

**Parameters in bold** are required and must be set by the user.

Parameters can be set in two ways:

1. Storing parameters in a configuration file using the ``-params-file`` option, e.g.:

.. code-block:: yaml
                
    liftover: true
    target_build: GRCh38

See :ref:`params file` for more details.

2. In a terminal using two dashes, e.g.:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc \
        -profile test,docker \
        --liftover \
        --target_build GRCh38
   
Parameters with a single dash (``-profile``) configure nextflow directly.

Setting parameters with a configuration file is the recommended method of
working with the pipeline, because it helps you to keep track of your analysis.

For background about max job request options, see :ref:`big job`.


.. jsonschema:: ../../nextflow_schema.json 
    :lift_description:
    :lift_definitions:
    :auto_target:
    :auto_reference:
    :hide_key: /**/allOf,/**/institutional_config_options
 

 
