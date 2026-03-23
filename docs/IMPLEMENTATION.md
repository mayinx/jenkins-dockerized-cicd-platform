# Jenkins Implementation Diary

## 🛠️ Task 1: Resolving Outdated Dockerfile References

The provided `Dockerfile` from the course materials was deprecated and caused immediate build failures. Below are the specific issues identified and the steps taken to resolve them.

### 1.1 The Issue: Version Mismatch & "Dependency Hell"
The original base image `FROM jenkins/jenkins:2.361.4-jdk11` (released in 2022) used an outdated Jenkins core and Java version. When attempting to install plugins, the `jenkins-plugin-cli` failed with the following error:

> `ERROR [6/6] RUN jenkins-plugin-cli --plugins "blueocean:1.25.6 docker-workflow:1.29"`  
> **Reason:** `Multiple plugin prerequisites not met: requires a greater version of Jenkins (2.479.3) than 2.361.4`

Modern Jenkins plugins now require **Java 17** and a more recent Jenkins core to function.

### 1.2 The Solution: Modernizing the Build
We updated the `Dockerfile` to use a modern LTS (Long-Term Support) version and decoupled the plugin versions to allow the manager to resolve the best compatible fit automatically.

**Updated Dockerfile Snippet:**
~~~dockerfile
# Fixed: Use a modern LTS version on JDK 17
# Previously: FROM jenkins/jenkins:2.361.4-jdk11
FROM jenkins/jenkins:lts-jdk17
USER root

# ... (Standard Docker CLI installation steps) ...

USER jenkins
# Fixed: Removing specific versions allows the CLI to auto-resolve 
# compatible dependencies, preventing version conflicts.
# Previously: RUN jenkins-plugin-cli --plugins "blueocean:1.25.6 docker-workflow:1.29"
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow"
~~~

**Build Command Update:**
The image tag was updated in the docker build command to reflect the new LTS base:
~~~bash
# Previously: docker build -t myjenkins-blueocean:2.361.4-1 .
docker build -t myjenkins-blueocean:lts .
~~~

---

## 🚀 Task 2: Jenkins & Docker-in-Docker (DinD) Implementation

To enable Jenkins to execute Docker commands, we implemented a **Sidecar Architecture**. In this setup, the Jenkins Controller acts as a "Remote Control" for a separate Docker Engine container.

### 2.1 Launching the Jenkins Controller
The following command connects the Jenkins UI to the existing `jenkins-docker` (DinD) network (due to the updated Dockerfile it was necessary to update the following docker run command slightly as well).

~~~bash
# Previously (last line): myjenkins-blueocean:2.361.4-1
docker run \
  --name jenkins-blueocean \                         # Assigns a readable name to the container
  --restart=on-failure \                             # Automatically restarts Jenkins if it crashes
  --detach \                                         # Runs the container in the background
  --network jenkins \                                # Joins the shared 'jenkins' bridge network
  --env DOCKER_HOST=tcp://docker:2376 \              # Points Jenkins to the Docker Engine container
  --env DOCKER_CERT_PATH=/certs/client \             # Internal path for TLS handshake certificates
  --env DOCKER_TLS_VERIFY=1 \                        # Enables encrypted communication with the Engine
  --publish 8080:8080 \                              # Web UI Access (Host:Container)
  --publish 50000:50000 \                            # JNLP port for Jenkins agent communication
  --volume jenkins-data:/var/jenkins_home \          # Persistent storage for jobs, users, and configs
  --volume jenkins-docker-certs:/certs/client:ro \   # Mounts security certs from DinD (Read-Only)
  myjenkins-blueocean:lts                            # The updated custom image
~~~

### 2.2 Architecture Overview: Docker-outside-of-Docker
This setup follows the **Docker-outside-of-Docker (DooD)** pattern. Jenkins is a client sending instructions over a network socket to a dedicated engine.

* **The Client:** Jenkins Controller container (UI + Docker CLI).
* **The Server:** `jenkins-docker` container (The actual Docker Daemon/Engine).

---

## 🖥️ Task 3: Initial Setup & Evidence

Once the containers are healthy, the Jenkins UI is accessible at `http://localhost:8080`.

**Evidence: Initial Unlock Screen**
To retrieve the initial administrator password required for the first login:
~~~bash
docker exec jenkins-blueocean cat /var/jenkins_home/secrets/initialAdminPassword
~~~

*(Insert Screenshot here: Jenkins "Unlock" page showing the password prompt)*

---

## 🛠️ Automation with Makefile

To avoid manual errors and simplify the deployment, a Makefile was created to standardize the workflow:

- `make build`: Rebuilds the modern Jenkins image.
- `make run`:   Deploys the container with all network and volume mappings.
- `make clean`: Removes the container to allow for a fresh start.












## Setup jenkins

after running teh above comamdn, we are able to visit `localhost:8080` (or on a vm <ip-address-vm:8080> 


TODO: Put evidence in here - at least teh initial screen or so