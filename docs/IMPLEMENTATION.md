## Fix dockerfiles oudated refgerences
Teh porovoided dockerfiel was outdate and needed various updates:

We had to change the dockerfile to use a use a modern LTS version of Jenkins instead of teh outdated  "FROM jenkins/jenkins:2.361.4-jdk11" from 2022
(teh ootdated version throw ERRORS liek 
" => ERROR [6/6] RUN jenkins-plugin-cli --plugins "blueocean:1.25.6 docker-workflow:1.29"                                                                            11.8s"
+  
"ERROR: failed to build: failed to solve: process "/bin/sh -c jenkins-plugin-cli --plugins \"blueocean:1.25.6 docker-workflow:1.29\"" did not complete successfully: exit code: 1" 
due to "Multiple plugin prerequisites not met:" - i.e.  "requires a greater version of Jenkins (2.479.3) than 2.361.4" error.


So we need to update a) the FROM-command -part as well as b) the RUN command that is too specific / coupled to a specific versaion of the blueocean docekr-wirkflow :

# old
FROM jenkins/jenkins:lts-jdk17

# update

~~~bash
# Fixed: Use a modern LTS version
FROM jenkins/jenkins:lts-jdk17
# ...
# Fixed: Removing specific versions allows the CLI to find the best fit for your Jenkins core
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow"
~~~


--plugins "blueocean docker-workflow": By removing the specific :1.25.6 versions, the plugin manager will automatically resolve and download versions that are compatible with your Jenkins version, saving you from manual dependency hell.

We need to change the docker build command  as well :

From 
    docker build -t myjenkins-blueocean:2.361.4-1 .

To 
    docker build -t myjenkins-blueocean:lts .


... and c) we need to update the docker run command (to use `myjenkins-blueocean:lts` instead of  `myjenkins-blueocean:2.361.4-1` )

~~~bash
docker run \
  --name jenkins-blueocean \
  --restart=on-failure \
  --detach \
  --network jenkins \
  --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=/certs/client \
  --env DOCKER_TLS_VERIFY=1 \
  --publish 8080:8080 \
  --publish 50000:50000 \
  --volume jenkins-data:/var/jenkins_home \
  --volume jenkins-docker-certs:/certs/client:ro \
  myjenkins-blueocean:lts
~~~bash
    ------------




## TODO: Doc Docekr run here ! 

### Jenkins & Docker-in-Docker (DinD) Implementation
To run the Jenkins controller with the ability to execute Docker commands, we use the following configuration. This setup uses a Sidecar architecture: one container runs the Docker Engine (jenkins-docker), and this container runs the Jenkins UI and CLI.


~~~bash
docker run \
  --name jenkins-blueocean \                        # Assigns a readable name to the container
  --restart=on-failure \                            # Automatically restarts Jenkins if it crashes
  --detach \                                        # Runs the container in the background (released terminal)
  --network jenkins \                               # Connects to the 'jenkins' bridge network to talk to the DinD container
  --env DOCKER_HOST=tcp://docker:2376 \             # Points Jenkins to the Docker Engine container on the same network
  --env DOCKER_CERT_PATH=/certs/client \            # Path inside the container to find security certificates
  --env DOCKER_TLS_VERIFY=1 \                       # Enables encrypted communication with the Docker Engine
  --publish 8080:8080 \                             # Maps [Your Host Port]:[Jenkins Internal Port] for Web UI access
  --publish 50000:50000 \                           # Maps the port used for Jenkins agent communication (JNLP)
  --volume jenkins-data:/var/jenkins_home \         # Persistent storage for jobs, users, and configs
  --volume jenkins-docker-certs:/certs/client:ro \  # Mounts the TLS certs from the DinD container (Read-Only)
  myjenkins-blueocean:lts                           # The custom image we built with Docker CLI and BlueOcean
~~~

### Fazit: Architecture

  This setup follows the **Docker-outside-of-Docker**-pattern. Jenkins acts as the client/remote control, while a separate container (jenkins-docker) acts as the actual worker engine.



## Setup jenkins

after running teh above comamdn, we are able to visit localhost:8080 (or on a vm <ip-address-vm:8080> 