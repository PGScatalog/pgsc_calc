.. _effect type:

How to set effect type of variants in a scoring file
====================================================

Some polygenic scores may specify an effect type for each variant, for example
`PGS000802`_. Effect weights can be dominant, recessive, or additive (the
default i.e., not dominant or recessive). Setting recessive or dominant effects
will change `allelic dosages`_ when calculating a score.

Scorefile structure with effect types
-------------------------------------

Two additional columns are required to specify the effect type of each variant:

.. list-table:: Optional effect type columns
   :widths: 50 50
   :header-rows: 1

   * - is_dominant
     - is_recessive
   * - TRUE
     - FALSE

These optional columns **must** be present after the four mandatory columns
described in :ref:`custom scorefile setup`. These optional columns follow the
structure described in the PGS Catalog `scoring file format v2.0`_ and should be
included after the effect_weight column.

Three possible effect types can be represented for each variant:

- Additive: both columns are FALSE
- Recessive: is_recessive is TRUE and is_dominant is FALSE
- Dominant: is_dominant is TRUE and is_recessive is FALSE

.. note:: The is_dominant and is_recessive columns are mutually exclusive (a
          variant cannot have a dominant and recessive effect type).

A scoring file with multiple effect types cannot contain multiple scores as
described in :ref:`multiple`. However, using star (``*``) characters to match
multiple scoring files will still work.

.. _`PGS000802`: https://www.pgscatalog.org/score/PGS000802/      
.. _`allelic dosages`: https://www.cog-genomics.org/plink/2.0/score
.. _`scoring file format v2.0`: https://www.pgscatalog.org/downloads/#scoring_header

