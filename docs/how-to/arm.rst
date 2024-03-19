.. _arm:

How do I run the pipeline on an M1 Mac?
=======================================

If you have a modern Mac you'll need to use the ``docker`` execution profile to
run the pipeline on computers with the ``arm64`` architecture. An extra
``arm`` profile can be used to get the pipeline working.

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc \
        -profile docker,test,arm

The default platform is ``amd64``, so if you're not running on an ARM computer
you don't need to include this extra profile. If you don't set ``arm`` profile on M1
Macs, you'll probably get a segmentation fault during variant matching:

.. code-block:: console

    WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested
    <jemalloc>: MADV_DONTNEED does not work (memset will be used instead)
    <jemalloc>: (This is the expected behaviour if you are running under QEMU)
    qemu: uncaught target signal 11 (Segmentation fault) - core dumped
    .command.sh: line 2:    69 Segmentation fault      match_variants --min_overlap 0.75 --dataset cineca_synthetic_subset --scorefile scorefiles.txt --target "$PWD/*.vars" --split -n 2 --outdir $PWD -v

The pipeline has been developed and tested using Docker desktop on an M1 Macbook.

``pgsc_calc`` seems slow on a Mac
---------------------------------

Running ``pgsc_calc`` on a mac will generally be slower than running on
Linux. This is because the workflow is running in a Linux virtual machine on top
of macOS. Some things to consider:

* Enable `VirtIO`_ to improve I/O performance
* `Allocate more`_ CPU / RAM to the Docker Desktop virtual machine
* Run big jobs on Linux

.. _VirtIO: https://www.docker.com/blog/speed-boost-achievement-unlocked-on-docker-desktop-4-6-for-mac/
.. _Allocate more: https://docs.docker.com/desktop/settings/mac/#advanced-1
