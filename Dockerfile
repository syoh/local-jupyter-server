FROM jupyter/datascience-notebook:notebook-6.1.5

# start binder compatibility
# from https://mybinder.readthedocs.io/en/latest/tutorials/dockerfile.html

ARG NB_USER
ARG NB_UID
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

# Install e1071 R package (dependency of the caret R package)
RUN conda install --quiet --yes r-e1071

USER root

# Rstudio Pre-requisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        psmisc \
        libapparmor1 \
        lsb-release \
        libclang-dev \
        zip unzip \
        tree && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 

ENV PATH=$PATH:/usr/lib/rstudio-server/bin \
    R_HOME=/opt/conda/lib/R
ARG LITTLER=$R_HOME/library/littler

RUN \
    # download R studio
    curl --silent -L --fail https://s3.amazonaws.com/rstudio-ide-build/server/bionic/amd64/rstudio-server-1.2.1578-amd64.deb > /tmp/rstudio.deb && \
    echo '81f72d5f986a776eee0f11e69a536fb7 /tmp/rstudio.deb' | md5sum -c - && \
    \
    # install R studio
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/rstudio.deb && \
    rm /tmp/rstudio.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
    
    # setting default CRAN mirror
RUN echo "local({" \
    "   r <- getOption('repos');" \
    "   r['CRAN'] <- 'https://cloud.r-project.org';" \
    "   options(repos = r);" \
    "})" > $R_HOME/etc/Rprofile.site && \
    \
    # littler provides install2.r script
    R -e "install.packages(c('littler', 'docopt'))" && \
    \
    # modifying littler scripts to conda R location
    sed -i 's/\/usr\/local\/lib\/R\/site-library/\/opt\/conda\/lib\/R\/library/g' \
        ${LITTLER}/examples/*.r && \
	ln -s ${LITTLER}/bin/r ${LITTLER}/examples/*.r /usr/local/bin/ && \
	echo "$R_HOME/lib" | sudo tee -a /etc/ld.so.conf.d/littler.conf && \
	ldconfig && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

RUN chown -R ${NB_UID} ${HOME}

USER ${NB_USER}

COPY . ${HOME}/work
# COPY jupyter_notebook_config.py ${HOME}/.jupyter/

RUN pip install \
        jupyter-server-proxy==1.5.3 \
        jupyter-rsession-proxy==1.2.0 \
        jupyterlab-git==0.23.3 \
        cookiecutter==1.7.2 \
        jupyter_http_over_ws>=0.0.7 && \
    jupyter serverextension enable --py jupyter_http_over_ws && \
    jupyter labextension install @jupyterlab/server-proxy && \
    jupyter lab build

