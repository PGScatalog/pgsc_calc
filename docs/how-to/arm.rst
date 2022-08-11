.. _arm:

How do I run the pipeline on an M1 Mac?
=======================================

If you have a modern Mac you'll need to use the ``docker`` execution profile to
run the pipeline on computers with the ``arm64`` architecture. The
``--platform`` parameter can be used to get the pipeline working.

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc \
        -profile docker,test \
        --platform arm64

The default platform is ``amd64``, so if you're not running on an ARM computer
you don't need to include this parameter. If you don't set ``--platform`` on M1
Macs, you'll probably get a segmentation fault during variant matching:

.. code-block:: console

    WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested
    <jemalloc>: MADV_DONTNEED does not work (memset will be used instead)
    <jemalloc>: (This is the expected behaviour if you are running under QEMU)
    qemu: uncaught target signal 11 (Segmentation fault) - core dumped
    .command.sh: line 2:    69 Segmentation fault      match_variants --min_overlap 0.75 --dataset cineca_synthetic_subset --scorefile scorefiles.txt --target "$PWD/*.vars" --split -n 2 --outdir $PWD -v

The pipeline has been tested using Docker desktop on an M1 Macbook. Some simpler
parts of the pipeline run using qemu ``amd64`` emulation, but CPU intensive
processes will run natively on arm64 docker images.
