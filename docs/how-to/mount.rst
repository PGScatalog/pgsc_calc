
.. _mount:

How do I mount non-standard directories in singularity?
=======================================================

In some situations you may get ``FileNotFound`` errors with the singularity profile even if the file definitely exists.

If your sensitive genomic data are stored in a non-standard Linux directory, then containers may need extra configuration to mount the directory correctly

This problem probably affects you if:

- you can run the test profile OK on singularity
- you get ``FileNotFound`` errors when working with your own data
- you are certain the file path reported in the error does exist and is accessible to you
  
Create a new nextflow configuration file `as described here`_:

.. code-block:: text

    singularity {
      enabled = true
      autoMounts = true
      runOptions = '-B /path/to/genomes'
    }

.. _`as described here`:  https://github.com/PGScatalog/pgsc_calc/issues/158#issuecomment-1713783129

You will need to edit ``runOptions`` to match the path to your local directory containing sensitive data.

And run the calculator with the extra parameter ``-c mount.config``.

Another possible solution is to test your own data with the ``conda`` profile, which doesn't require extra configuration to work with non-standard directories. 
