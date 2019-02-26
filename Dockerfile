FROM neurodebian:stretch-non-free
MAINTAINER Timothy Weng <timothy-weng@uiowa.edu>
LABEL software='RestingState'
LABEL version="0.0.1_beta"

# Don't ask for user input when installing
ARG DEBIAN_FRONTEND=noninteractive

# for installing the image package for octave
RUN echo "deb http://ftp.debian.org/debian stretch-backports main" >> /etc/apt/sources.list.d/neurodebian.sources.list

# install debian essentials
RUN apt-get update -qq && apt-get install -yq --no-install-recommends  \
    apt-utils \
  	bzip2 \
    ca-certificates \
    curl \
    git \
    unzip \
    rsync \
    parallel \
    make

# install octave
RUN apt-get -t stretch-backports install -yq --no-install-recommends \
  liboctave-dev \
  octave

# install the image package from octave
RUN octave --eval "pkg install -forge image"
RUN touch ~/.octaverc && echo "pkg load image" > ~/.octaverc

# install the scientific/neuroimaging packages we need
RUN apt-get update -qq && apt-get install -yq --no-install-recommends  \
    afni \
    fsl \
    fsl-atlases

# Installing and setting up miniconda
RUN curl -sSLO https://repo.anaconda.com/miniconda/Miniconda2-latest-Linux-x86_64.sh && \
    bash Miniconda2-latest-Linux-x86_64.sh -b -p /usr/local/miniconda && \
    rm Miniconda2-latest-Linux-x86_64.sh

ENV PATH=/usr/local/miniconda/bin:$PATH \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN conda install -y mkl=2017.0.1 mkl-service;  sync &&\
    conda install -y future \
                     numpy=1.12.0 \
                     scipy=0.18.1 \
                     seaborn \
                     jupyter; sync &&  \
    chmod -R a+rX /usr/local/miniconda; sync && \
    chmod +x /usr/local/miniconda/bin/*; sync && \
    conda clean --all -y; sync && \
    conda clean -tipsy && sync

# Installing and setting up ICA_AROMA
RUN mkdir -p /opt/ICA-AROMA && \
  curl -sSL "https://github.com/rhr-pruim/ICA-AROMA/archive/v0.4.1-beta.tar.gz" \
  | tar -xzC /opt/ICA-AROMA --strip-components 1 && \
  chmod +x /opt/ICA-AROMA/ICA_AROMA.py


# Copy the code in RestingState to the container
COPY . /opt/RestingState

# Make the code executable
RUN chmod +x /opt/RestingState/*.sh && \
    chmod +x /opt/RestingState/*.m

# Configure the environment
ENV FSLDIR=/usr/share/fsl/5.0 \
    FSLOUTPUTTYPE=NIFTI_GZ \
    FSLMULTIFILEQUIT=TRUE \
    POSSUMDIR=/usr/share/fsl/5.0 \
    LD_LIBRARY_PATH=/usr/lib/fsl/5.0:$LD_LIBRARY_PATH \
    FSLTCLSH=/usr/bin/tclsh \
    FSLWISH=/usr/bin/wish \
    PATH="/opt/ICA-AROMA:/opt/RestingState:/usr/lib/afni/bin/:/usr/lib/fsl/5.0:$PATH"

# clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# How users interact with the container
ENTRYPOINT ["/opt/RestingState/processRestingState_bids_wrapper.sh"]
