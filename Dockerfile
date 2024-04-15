# A dockerfile to build a docker image for the application
# Use the official Python base image
FROM python

# Set the working directory in the container
WORKDIR /app

# Install pipenv
RUN pip install pipenv

VOLUME [ "/workspace", "/var/run/docker.sock" ]


# # Install a few prerequisite packages which let apt use packages over HTTPS
# RUN apt-get install -y \
#     apt-transport-https \
#     ca-certificates \
#     curl \
#     software-properties-common

# # Add the GPG key for the official Docker repository to your system
# RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# # Add the Docker repository to APT sources
# RUN add-apt-repository \
#    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
#    $(lsb_release -cs) \
#    stable"

# # Update the package database with the Docker packages from the newly added repo
# RUN apt-get update

# # Install Docker
# RUN apt-get install -y docker-ce

# Install Node.js (needed for jsii)
RUN apt-get update && apt-get install -y curl && \
    curl -sL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs



# Copy the requirements file to the container
# Copy the Pipfile and Pipfile.lock to the container
COPY Pipfile Pipfile.lock ./

# Generate requirements.txt from Pipenv
RUN pipenv requirements > requirements.txt

# Install the Python dependencies
RUN pip install -r requirements.txt

# Copy the application code to the container
COPY . .

EXPOSE 50051

ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Set the entry point for the container
CMD ["python", "./provider/main.py"]