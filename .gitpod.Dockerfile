FROM gitpod/workspace-full

# update things
USER root
RUN apt-get update -qqy && apt-get upgrade -qqy

# install google-cloud-sdk
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get install \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get -qqy update && \
    apt-get install \
      google-cloud-sdk

# and we're back
USER gitpod