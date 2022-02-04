API
===

``pgsc_calc`` has two main use cases:

- A bioinformatician or data scientist wants to calculate some polygenic scores
  using an Unixy operating system and a terminal
- A normal person (e.g. a biologist or other researcher) wants to calculate some
  polygenic scores using a web browser

To simplify the second use case, the workflow is designed to be launched
programmatically on a `private cloud`_ using an API. API parameters are specified
using JSON. The web platform is still under development.

.. _private cloud: http://www.embassycloud.org/

Minimal example
---------------

Specifying target genomes with JSON
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. literalinclude:: ../assets/api_examples/input.json
  :language: JSON

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. literalinclude:: ../assets/api_examples/params.json
  :language: JSON

Some other parameters need to be set for the workflow to run, which are
specified in a simple JSON object. Nextflow supports setting parameters via JSON
with the ``-params-file`` flag. This object can be complex, because many
optional parameters can be set here. A minimal workflow parameter object must
contain:

- The path to a :term:`scoring file` OR
- An :term:`accession` in the :term:`PGS Catalog` (replace ``--accession`` with
  scorefile)
- The format must be "json"

The JSON :ref:`schema` specifies optional parameters in full.

API call
~~~~~~~~

.. literalinclude:: ../assets/api_examples/call.json

The complete call also includes some nextflow configuration. The workflow is
assigned a unique identifier at launch to monitor its progress. Nextflow has
some requirements for the Kubernetes executor, so the work
directory must be unique and be in a `ReadWriteMany persistent volume claim`_ that
is accessible by the :term:`driver pod` and all :term:`worker pods`.

.. _ReadWriteMany persistent volume claim: https://www.nextflow.io/docs/latest/kubernetes.html#requirements

Schema
------

This documentation is useful for a human, but not a computer, so we wrote a
document (`a JSON schema`_) that describes the data format. The schema is used
to automatically validate data submitted to the workflow via the API.

.. _a JSON schema: https://json-schema.org/

.. jsonschema:: ../assets/schema_k8s.json

Implementation details
----------------------

The API is designed using an event-driven approach with `Argo
Events`_. Briefly, a sensor constantly listens on a Kubernetes cluster for Kafka
messages to launch the pipeline. Once the message is received, a nextflow driver
pod is created and the workflow is executed using the `K8S executor`_. The
status of the workflow instance is reported using Nextflow's `weblog`_ and
a second sensor. We didn't have Nextflow Tower at the time.

.. _Argo Events: https://argoproj.github.io/argo-events/
.. _K8S executor: https://www.nextflow.io/docs/latest/kubernetes.html
.. _weblog: https://www.nextflow.io/docs/latest/tracing.html#weblog-via-http

