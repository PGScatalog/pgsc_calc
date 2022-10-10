# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html
import os.path
import re
import subprocess

# -- Path setup --------------------------------------------------------------

# If extensions (or modules to document with autodoc) are in another directory,
# add these directories to sys.path here. If the directory is relative to the
# documentation root, use os.path.abspath to make it absolute, like shown here.
#
# import os
# import sys
# sys.path.insert(0, os.path.abspath('.'))


# -- Project information -----------------------------------------------------

project = 'Polygenic Score (PGS) Catalog Calculator'
copyright = 'Polygenic Score (PGS) Catalog team (licensed under Apache License V2)'
# author = 'Polygenic Score (PGS) Catalog team'


# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
# ones.
extensions = [
    'sphinx.ext.githubpages',
    'sphinx.ext.autosectionlabel',
    'sphinx.ext.autodoc',
    'sphinx-jsonschema',
    'sphinxemoji.sphinxemoji'
]

nitpicky = True

# Add any paths that contain templates here, relative to this directory.
templates_path = ['_templates']

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# -- Options for HTML output -------------------------------------------------

# The theme to use for HTML and HTML Help pages.  See the documentation for
# a list of builtin themes.
#
html_theme = 'sphinx_book_theme'

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
# html_static_path = ['_static']

html_sidebars = {
    "**": [
        "search-field.html",
        "globaltoc.html"]
}

# for link checking
user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:25.0) Gecko/20100101 Firefox/25.0'

html_theme_options = {
    "repository_url": "https://github.com/pgscatalog/pgsc_calc",
    "use_repository_button": False,
    "use_issues_button": False,
    "extra_navbar": ""
}

def write_containers():
    base_singularity = get_unique_containers("singularity", "depot")  # biocontainers
    custom_singularity = get_unique_containers("singularity", "oras")  # private containers
    base_docker = get_unique_containers("docker", "quay")
    custom_docker = get_unique_containers("docker", "\"dockerhub")
    if not os.path.exists("_build"):
        os.mkdir("_build")

    with open('_build/singularity_containers.txt', 'w') as f:
        f.write('\n'.join(base_singularity + custom_singularity))

    with open('_build/docker_containers.txt', 'w') as f:
        f.write('\n'.join(base_docker + custom_docker))


def get_unique_containers(engine: str, grep_string: str) -> list[str]:
    git: subprocess.CompletedProcess = subprocess.run(["git", "grep", "-h", grep_string, "../*.nf"],
                                                      capture_output=True)
    messy_containers: str = git.stdout.decode("utf-8").strip()
    match engine:
        case "docker":
            # custom containers use double quotes for closures
            containers = list(set(re.findall(r'"([^"]*)"', messy_containers)))
            if not containers:
                # biocontainers use single quotes
                containers = list(set(re.findall('\'([^\']*)\'', messy_containers)))
        case "singularity":
            # all singularity images use single quotes
            containers = list(set(re.findall('\'([^\']*)\'', messy_containers)))

    return containers


write_containers()
