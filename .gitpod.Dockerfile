FROM gitpod/workspace-full

<<<<<<< HEAD
# be root
USER root

# update things
=======
# update things
USER root
>>>>>>> afc08a552faa657d00830ff31040a954217c7e9f
RUN apt-get update -qqy && apt-get upgrade -qqy

# install google-cloud-sdk
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"
<<<<<<< HEAD
RUN apt-get -qqy update && apt-get -qqy install \
=======
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get install \
>>>>>>> afc08a552faa657d00830ff31040a954217c7e9f
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg && \
<<<<<<< HEAD
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get -qqy update && apt-get -qqy install \
=======
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get -qqy update && \
    apt-get install \
>>>>>>> afc08a552faa657d00830ff31040a954217c7e9f
      google-cloud-sdk

# and we're back
USER gitpod