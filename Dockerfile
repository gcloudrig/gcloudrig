FROM node:10

RUN apt-get update -qqy && apt-get upgrade -qqy

# Downloading gcloud package
RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz

# Installing the package
RUN mkdir -p /usr/local/gcloud \
  && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
  && /usr/local/gcloud/google-cloud-sdk/install.sh

# Adding the package path to local
ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

WORKDIR /usr/src/app
COPY . .

RUN gcloud auth activate-service-account --key-file ./service_account.json

WORKDIR /usr/src/app/api
RUN npm ci --only=production

EXPOSE 8080
CMD [ "node", "index.js" ]