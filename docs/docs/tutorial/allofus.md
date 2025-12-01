---
sidebar_label: All of Us deployment
description: How to calculate polygenic scores on the All of Us cohort
---

# All of Us Researcher Workbench tutorial

This tutorial describes how to calculate [PGS000018](https://www.pgscatalog.org/score/PGS000018/), a polygenic score (PGS) 
which measures coronary artery disease risk.

The simplest way to work with the All of Us data is to use a run [nextflow in a terminal](https://support.researchallofus.org/hc/en-us/articles/4811899197076-Workflows-in-the-All-of-Us-Researcher-Workbench-Nextflow-and-Cromwell), 
which works like a local Linux machine.

By the end of this tutorial you should understand how to use the PGS Catalog Calculator to calculate PGS in the All of Us cohort.

## Before you get started

You'll need:
* [Approval to access](https://www.researchallofus.org/register/) All of Us data.
* A project with access to [Controlled Tier](https://www.researchallofus.org/data-tools/data-access/) data (contains genotypes) in the Researcher Workbench.

## 1. Install nextflow & conda

### Install nextflow

First, follow the official [instructions for how to install nextflow](https://workbench.researchallofus.org/workspaces/aou-rw-5b81a011/howtousenextflowintheresearcherworkbenchv7/data?_gl=1*1hxzxb7*_ga*MjgzMTM4MzgyLjE3MzM5MjQxOTQ.*_ga_K8QTQT89XP*czE3NjQ2MDc4OTgkbzIwJGcxJHQxNzY0NjA4ODg1JGoyOSRsMCRoMA).

### Install conda

The version of java in the workbench is slightly outdated for newer versions of nextflow. The first step of the tutorial
is to open a terminal, and [install conda (official AoU docs)](https://support.researchallofus.org/hc/en-us/articles/31335822037524-How-to-install-Miniconda-Anaconda-in-the-Researcher-Workbench):

```bash
# Create the directory ~/miniconda3 if it does not already exist
$ mkdir -p ~/miniconda3

# Download the latest Miniconda3 installer for Linux x86_64 architecture
# and save it as ~/miniconda3/miniconda.sh
$ wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh

# Run the Miniconda3 installer script in batch mode (-b), update the installation (-u),
# and specify the installation path as ~/miniconda3 (-p ~/miniconda3)
$ bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3

# Remove the Miniconda3 installer script after the installation is complete
$ rm ~/miniconda3/miniconda.sh

# initialization:
$ ~/miniconda3/bin/conda init bash

# use immediately in the current shell session
$ source ~/.bashrc

# check conda environments
$ conda info --env
# Locate the path to the conda executable
$ which conda
```

Once you have sucessfully installed conda, you can create & activate an environment:
```bash
# create conda environment
$ conda create -n enxf python=3.12 -y

# activate environment
$ conda activate enxf

# install more recent java version
(enxf) $ conda install -c conda-forge openjdk=17

# check that java is installed
(enxf) $ java -version
openjdk version "17.0.3-internal" 2022-04-19
OpenJDK Runtime Environment (build 17.0.3-internal+0-adhoc..src)
OpenJDK 64-Bit Server VM (build 17.0.3-internal+0-adhoc..src, mixed mode, sharing)
```
