# Variables to avoid repeating yourself
IMAGE_NAME = myjenkins-blueocean
TAG = lts
CONTAINER_NAME = jenkins-blueocean
NETWORK = jenkins

.PHONY: build run stop clean

# Build the custom Jenkins image
build:
	docker build -t $(IMAGE_NAME):$(TAG) .

# Run the Jenkins container with all the complex networking
run:
	docker run \
	  --name $(CONTAINER_NAME) \
	  --restart=on-failure \
	  --detach \
	  --network $(NETWORK) \
	  --env DOCKER_HOST=tcp://docker:2376 \
	  --env DOCKER_CERT_PATH=/certs/client \
	  --env DOCKER_TLS_VERIFY=1 \
	  --publish 8080:8080 \
	  --publish 50000:50000 \
	  --volume jenkins-data:/var/jenkins_home \
	  --volume jenkins-docker-certs:/certs/client:ro \
	  $(IMAGE_NAME):$(TAG)

# Stop the container
stop:
	docker stop $(CONTAINER_NAME)

# Remove the container and start fresh (leaves volumes alone)
clean:
	docker rm -f $(CONTAINER_NAME)