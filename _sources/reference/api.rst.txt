API reference
=============

``pgsc_calc`` has two main use cases:

- A bioinformatician or data scientist wants to calculate some polygenic scores
  using an Unixy operating system and a terminal
- A normal person (e.g. a biologist or other researcher) wants to calculate some
  polygenic scores using a web browser

To simplify the second use case, the workflow is designed to be launched
programmatically on a `private cloud`_ using an API. API parameters are specified
using JSON. The web platform is still under development.

.. _private cloud: http://www.embassycloud.org/

Specifying target genomes with JSON
-----------------------------------

.. literalinclude:: ../../assets/api_examples/input.json
  :language: JSON

             
Specifying workflow parameters with JSON
----------------------------------------

.. literalinclude:: ../assets/api_examples/params.json
  :language: JSON

Complete API call
-----------------

.. literalinclude:: ../../assets/api_examples/call.json

API call schema
---------------------------

.. jsonschema:: ../../assets/schema_k8s.json

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

