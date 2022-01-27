API
===

``pgsc_calc`` is designed to be used in a terminal, but can also be launched
programmatically on a Kubernetes cluster. To simplify this process,
``pgsc_calc`` supports specifying target genomes and runtime parameters using
JSON.


Specifying target genomes with JSON
-----------------------------------

.. code-block:: json
                
    {
      "target_genomes": [
        {
          "sample": "example",
          "vcf_path": "path.vcf.gz",
          "chrom": 22
        }
      ]
    }   

Target genomes are specified as a JSON array. Each element of the array must:

- Contain an experiment identifier ("``sample``"). If genomic data are split
  across multiple files (e.g. per chromosome), then this identifier must be the
  same across split files
- Contain a path to a block gzipped Variant Call Format file ("``vcf_path``")
- Specify which chromosome the variants come from ("``chrom``"). If the data are
  not split, then chrom can be null.

The target genome array must contain at least one item, and each item must be
unique.

This JSON data must be saved to a file and used with the workflow parameter
``--input`` in combination with ``--format json``. The file extension should end
with ``.json``.

Specifying workflow parameters with JSON
----------------------------------------

JSON schema
-----------
