# Variables
IMAGE_NAME = myjenkins-blueocean
TAG = lts
CONT_JENKINS = jenkins-blueocean
CONT_DOCKER = jenkins-docker
NETWORK = jenkins

.PHONY: setup build run login stop clean

# Task 0: Infrastructure Setup
setup:
	docker network create $(NETWORK) || true
		docker run \
		--name $(CONT_DOCKER) \
		--rm \
		--detach \
		--privileged \
		--network $(NETWORK) \
		--network-alias docker \
		--env DOCKER_TLS_CERTDIR=/certs \
		--volume jenkins-docker-certs:/certs/client \
		--volume jenkins-data:/var/jenkins_home \
		--publish 2376:2376 \
		docker:dind \
		--storage-driver overlay2

# Task 1: Build the custom Jenkins image
build:
	docker build -t $(IMAGE_NAME):$(TAG) .

# Task 2: Run the Jenkins container with all the complex networking
run:
	docker run \
	  --name $(CONT_JENKINS) \
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

# Task 3: Quick Login Helper
login:
	@docker exec $(CONT_JENKINS) cat /var/jenkins_home/secrets/initialAdminPassword

# Cleanup 

# Stop the container
stop:
	docker stop $(CONT_JENKINS) $(CONT_DOCKER) || true

# Remove the container and start fresh (leaves volumes alone)
clean:
	docker rm -f $(CONT_JENKINS) $(CONT_DOCKER) || true