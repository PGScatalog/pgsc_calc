.. _param ref:

Parameter reference
===================

The documentation below is automatically generated from the input schema and
contains additional technical detail. **Parameters in bold** are required and
must be set by the user.

Setting parameters
------------------

Parameters can be set in two ways:

1. Storing parameters in a configuration file using the ``-params-file``
   option. See :ref:`params file` for more details.

2. In a terminal using two dashes, e.g.:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc \
        -profile test,docker \
        --liftover \
        --target_build GRCh38
   
Parameters with a single dash (e.g. ``-profile``) configure nextflow directly.

Setting parameters with a configuration file is the recommended method of
working with the pipeline, because it helps you to keep track of your analysis.

For examples about setting max job request options, see :ref:`big job`.

Advanced parameters
-------------------

Some parameters have been hidden below to improve the readability of this
page. You can view the entire list by running:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc --help

Or by `downloading the schema`_ and opening it in a text editor

.. _downloading the schema: https://github.com/PGScatalog/pgsc_calc/blob/master/nextflow_schema.json

Parameter schema
----------------

.. jsonschema:: ../../nextflow_schema.json 
    :lift_description:
    :lift_definitions:
    :auto_target:
    :auto_reference:
    :hide_key: /**/allOf,/**/institutional_config_options
 

 
