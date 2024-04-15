# wrapper for docker images
ARG BASE_IMAGE

# Wrap any base image in this runtime wrapper
# Don't remove escaped $
FROM $BASE_IMAGE

# ARG RUNTIME_URI
# This needs to be published externally for terraform
ARG RUNTIME_URI

ENV WORKSPACE="/workspace"

# Don't remove escaped $
COPY runtime /bin/runtime
RUN chmod +x-rw /bin/runtime

# Inject original wrapped command here
# Don't remove escaped quotes
ENTRYPOINT ["/bin/runtime"]