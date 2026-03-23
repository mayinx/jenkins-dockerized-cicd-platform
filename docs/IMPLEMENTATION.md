# Implementation Diary for "Jenkins Docker CI/CD-Platform" 

A fully dockerized Jenkins CI/CD platform engineered with a Docker-in-Docker (DinD) sidecar architecture to provide a portable, automated environment for modern software delivery.

TODO: Proceed with "Create a Pipeline"!

TODO:; Perhaps we should split this up into phases 


Into / rationale: 
- encountering a broken legacy environment, analyzing the failure, modernizing the stack (Java 17/LTS), and then surgically patching a secondary dependency chain—all while automating the whole thing with a Makefile

## 📖 Introduction
Jenkins is the industry-standard automation server used to orchestrate **Continuous Integration (CI)** and **Continuous Deployment (CD)**. Unlike simpler tools (like GitHub Actions or GitLab CI), Jenkins offers deep extensibility through its plugin ecosystem, allowing it to integrate with virtually any tech stack. 

In this project, we move beyond a "standard" installation by deploying Jenkins as a **Dockerized Platform**. By using a **Sidecar Engine**, we enable Jenkins to build, test, and deploy Docker images without exposing the host machine's daemon, ensuring a portable and secure automation environment.


## 📖 Overview
This project documents the deployment of a modernized Jenkins environment using a **Sidecar (Docker-in-Docker) Architecture**. 

**The Goal:** To move away from deprecated configurations and establish a stable, Java 17-based CI/CD controller capable of executing Docker commands as a separate service. 

**Core Components:**
* **Jenkins Controller:** Modernized LTS image with pre-injected Blue Ocean and Docker-Workflow plugins.
* **Docker Engine (DinD):** A privileged sidecar container acting as the host for Jenkins build tasks.
* **Automation:** A unified `Makefile` to handle the entire infrastructure lifecycle.


**Info**
- This is an persistent environment (we used `jenkins-data` and `jenkins-docker-certs` volumes)
- So we can shut down the machine anytime, come back in a week, `run make setup` and `make run`, and everything (our users, jobs, and plugins) will still be there exactly as we left it.

## 🛠️ Task 0: Infrastructure Setup (Docker-in-Docker)

Before building the Jenkins Controller, we had to set up the execution environment—the Docker Engine that Jenkins will use to run builds.

### 0.1 Preparing the Network and Images
First, we created a dedicated bridge network and pulled the necessary official images.
~~~bash
docker network create jenkins
docker pull jenkins/jenkins
docker pull docker:dind
~~~

### 0.2 Running the Docker Engine (Sidecar)
We started the `jenkins-docker` container. This container acts as the actual "Daemon" that will execute the Docker commands sent by Jenkins.
~~~bash
docker run \
  --name jenkins-docker \
  --rm \
  --detach \
  --privileged \
  --network jenkins \
  --network-alias docker \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume jenkins-docker-certs:/certs/client \
  --volume jenkins-data:/var/jenkins_home \
  --publish 2376:2376 \
  docker:dind \
  --storage-driver overlay2
~~~

---

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

Once the containers are healthy, the Jenkins UI is accessible at `http://localhost:8080` (or via <ip-address-vm:8080> on a VM).

**Evidence: Initial Unlock Screen** 

![Figure 1: Jenkins Initial Unlock screen requiring the Administrator password retrieved via Docker exec.](/docs/evidence/01-jenkins-unlock-screen.png)
***Figure 1:** The initial "Unlock Jenkins" screen encountered after the first launch. This confirms the container is running and the web interface is accessible on port 8080.*

**Retrieving the Password**

Jenkins auto-generated an initial administrator password (`initialAdminPassword`) to the log and a specific file location. So there are two ways to retrieve that auto-generated admin password required for the first login:

1. **Via Docker Logs:**
   ~~~bash
   docker logs jenkins-blueocean
   ~~~
   *This displays the Jenkins startup console, where the password is printed between two rows of asterisks.*

2. **Via Direct File Access (Preferred for speed):**
   ~~~bash
   docker exec jenkins-blueocean cat /var/jenkins_home/secrets/initialAdminPassword
   ~~~

Just copypasta the passowrd over to the "Administrator password" field in the Unlock Screen displayed in the browser and hit "next". 

**Evidence: Welcome / Getting Started Screen** 

![Figure 2: Jenkins 'Getting Started' screen offering the choice between suggested plugins or manual selection.](/docs/evidence/02-jenkins-plugin-selection.png)
***Figure 2:** Post-login initialization screen verifies successful authentciation with the previously generated password.*

---

## ⚙️ Task 4: Configuration & Finalization

After logging in with the initial password, we followed these steps to finalize the environment:

### 1. Plugin Installation: Select "Install suggested plugins" to ensure basic pipeline functionality.

**Welcome / Getting Started Screen** 

![Figure 2: Jenkins 'Getting Started' screen offering the choice between suggested plugins or manual selection.](/docs/evidence/02-jenkins-plugin-selection.png)
***Figure 2:** Getting Started Screen offering the choice between suggested plugins or manual selection. In this step, we select **"Install suggested plugins"** to ensure the environment was pre-configured with the standard Pipeline and Git tools required for the course.*

**Implementation Note:** Choosing 'Suggested Plugins' at this stage provides the core dependencies for the `docker-workflow` and `blueocean` plugins we injected via the custom Dockerfile, ensuring a stable baseline for our CI/CD pipelines.

### 2. Admin User Creation: Set up a personal admin account to replace the temporary initial password.

**Admin Registration** 

![Figure 3: First Admin User registration form.](/docs/evidence/04-jenkins-create-admin.png)
***Figure 3:** Setting up the primary administrative account. This step replaces the temporary initial password with permanent, secure credentials for future sessions.*

Fill in the form and select "Save and Continue". Be sure not to forget the new credentials - teh auto-generated password from earlier is invalidated now. 

### 3. Instance Configuration: Confirmed the Jenkins Root URL (set to `http://localhost:8080/`). 

This setting is vital for the `$BUILD_URL` environment variable, ensuring that links generated in build logs or notifications point back to the correct controller address.

**Instance Configuration**

![Figure 3: Jenkins Instance Configuration screen for setting the root URL.](/docs/evidence/05-jenkins-instance-configuration.png)
***Figure 3:** Jenkins Instance Configuration screen for setting the Jenkins root URL. This configuration ensures that absolute links to Jenkins resources remain consistent across the environment, especially when using the BUILD_URL variable in pipeline scripts.*

**Options:**

- **Local machine**. Just leave the default http://localhost:8080/.
- **VM**: Use the public IP or the hostname provided by your cloud provider (e.g., http://1.2.3.4:8080/).

Selecting **"Save and Finish"** confirm that "Jenkins is ready":

**Jenkins is Ready: Setup Complete Confirmation**

![Figure 3.6: The final 'Jenkins is ready!' confirmation screen.](/docs/evidence/06-jenkins-setup-complete.png)
***Figure 3.6:** Successful completion of the Post-Installation Wizard. This confirms that all initial configurations (Security, Plugins, Admin User, and URL) are persisted and the controller is ready for production use.*

And selecting the button **"Save and Finish"** here brings us finally to the Dashboard: 

### 4. Dashboard Access: Confirmed access to the main Jenkins dashboard.

![Figure 4: Jenkins Main Dashboard after successful configuration.](/docs/evidence/07-jenkins-dashboard-main.png)
***Figure 4:** The Jenkins Main Dashboard after successful configuration, showing the "Create a job" button. This confirms the 'Welcome to Jenkins' state, where we can now begin creating 'New Items' (Jobs).*
 

---

## 📦 Task 5: Plugin Management 

### 5.1 Hotfix: Resolving Dependency Gaps (Post-Installation)

Upon reaching the dashboard the gear icon in teh top right ("Manage Jenkins") displayed a reed dot, indicating somethingh's amiss: Inspeciting this, an Error Screen was dispalyed with a flagged "Dependency Error". The Blue Ocean suite failed to load because the `json-path-api` plugin—a critical dependency—was missing from the initial installation.

**The Issue Identified:**
A cascade of failures occurred in the plugin ecosystem. The root cause was the missing `json-path-api` (2.9.0), which prevented the `Token Macro Plugin` from loading, which in turn disabled `Blue Ocean`.

**Evidence: Dependency Error Log**

![Figure 8: Unsatisfied dependencies error log in the Jenkins Management console.](/docs/evidence/08-jenkins-dependency-error.png)
***Figure 8:** The dependency error screen. This indicates a "cascade failure" where the missing `json-path-api` prevented `Token Macro` from loading, which ultimately disabled the entire `Blue Ocean` suite. Resolving this required an explicit addition to the Dockerfile.*

**Surgical Remediation:**
The `Dockerfile` was updated to explicitly include the missing API dependency to ensure a clean boot.

~~~dockerfile
# Fixed: Added 'json-path-api' to ensure the full dependency chain for Blue Ocean is met
# Previously: docker build -t myjenkins-blueocean:lts .
RUN jenkins-plugin-cli --plugins "json-path-api blueocean docker-workflow"
~~~

**Verification of Hotfix:**
After rebuilding the image (`make build`) and recreating the container (`make clean`, `make run`), the "Manage Jenkins" dashboard was re-inspected; the main dependency issues were resolved, leaving only non-critical system warnings which were addressed in the following assessment.

![Figure 9: "Manage Jenkins" dashboard after the hotfix.](/docs/evidence/09-jenkins-dependency-error-resolved.png)
***Figure 9:** "Manage Jenkins" dashboard after the fix showing just non-critical system warnings. The main dependency issues have been removed, confirming the Blue Ocean suite is now correctly loaded and active.*

### 5.1.1 Post-Fix Risk Assessment (Warnings)
After resolving the critical dependency errors, three non-blocking warnings remained in the management dashboard. These were evaluated and intentionally bypassed for this implementation:

* **Built-in Node Execution:** Jenkins warns against running builds on the controller for security. As this is a localized learning environment, distributed builds (Agents) were deemed out of scope.
* **Java 17 Lifecycle:** A warning regarding the upcoming EOL for Java 17 (March 2026) was noted. The current LTS-JDK17 image remains stable for the duration of this exercise.
* **CSP Header:** The Content Security Policy warning was dismissed to ensure maximum compatibility with Jenkins UI extensions and HTML reporting during the course.

**Result:** All critical (red) blockers are resolved; the environment is "Green" for project development.

### 5.2 Plugin Ecosystem
Accessed via **Manage Jenkins (Gear Icon) > Section "System Configuration" "Plugins"**, we can identify the following key areas:
* **Updates:** For security patches of existing tools.
* **Available:** To find new integrations (e.g., Kubernetes, Git).
* **Installed:** To verify the BlueOcean and Docker-Workflow plugins we added in our `Dockerfile`.

**Plugin Manager**

![Figure 10: "Manage Jenkins / Plugins" dashboard.](/docs/evidence/10-jenkins-plugins-manager.png)
***Figure 10:** Manage Jenkins / Plugins" dashboard offers various options to manage Plugins for Jenkins.*

## 6. Create a first Project to verify the Jenkins environment 
To verify the environment, we create a **Freestyle Project** named `hello-jenkins`:

### 1. Create a new Item (i.e. Jenkins Project)

From the dashboard, select **"+ New Item"**, enter an **item-name**, select **"Build a Free Style Project"** and hit **"Ok"**.

**Create a new Item (i.e. Jenkins Project)**

![Figure 11: Create a new Item.](/docs/evidence/11-jenkins-create-new-item.png)
***Figure 11:** Create a new Item as a Free-Style-Project.*

### 2. Configure - Create a Build Step 

**Config Screen of our new Jenkins-Project/Item** 

![Figure 12: Initial Project Config Screen.](/docs/evidence/12-jenkins-configuring-item.png)
***Figure 12:** Initial Project/Item Config Screen.*

Our minimal goal here is to display the usual "Hello World" in a terminal 

TO achieve thsi, we follow this steps: 

- Select "Build Steps" on the left menu and on teh right under "Buidl Steps" the dropodwon labelöed "+ Add Build Step" and in the dropdown the option "

**Add Build Step**

![Figure 13: Project/Item Config > Add Build Step.](/docs/evidence/13-jenkins-project-config-add-build-steps-section.png)
***Figure 13:** Project/Item Config > "Add Build Step".*

**Enter a simple Shell Script**

Select "execute Shell" from the options and enter some simple shell commands to be executed on build in the Comamnd Section of the displayed text field, f.i.:

~~~bash
echo "Hello World with Jenkins"
java -version
~~~

![Figure 14: Enter simple Shell Script.](/docs/evidence/14-jenkins-add-a-simple-shell-script.png)
***Figure 14:** Enter simple Shell Script to be executed on build.*

Hit **Save** will redirect to the Project Dashboard:  

![Figure 15: The Project Dashboard.](/docs/evidence/15-jenkins-project-dashboard.png)
***Figure 15:** The Project Dashboard.*

## Execute build ("Build Now")

![Figure 15: The Project Dashboard.](/docs/evidence/15-jenkins-project-dashboard.png)
***Figure 15:** The Project Dashboard.*

Now we click "Build Now" in the left sidebar to execute the build step and its associated shell script. A notification with a green checkmark is displayed and a new entry is added to the "Build History":    

**Evidence: Build History Success**

 ![Figure 16: Jenkins Build History showing a successful build.](/docs/evidence/16-jenkins-build-success.png)
***Figure 16:** The project dashboard after clicking 'Build Now'. The green checkmark and the build entry in the Build History confirm that the shell script was executed by the controller without errors.*

Each entry in the build history has several options to offer, available via the attached dropdown menu: 


**Available Build History Options**

 ![Figure 17: Available Build History Options.](/docs/evidence/17-jenklins-available-build-history-options.png)
***Figure 17:** Available Build History Options.*

Among others, we can inspect the terminal output and "Blue Ocean" to confirm that our shell script ran smoothly ad that Jenkins is correctly using JDK 17 as specified in our modernized `Dockerfile: 
 
**Evidence: Console Output Verification**

![Figure 18: The Jenkins Console Output showing 'Hello World from Jenkins' and Java version.](/docs/evidence/18-jenkins-build-console-output.png)
***Figure 18:** The Jenkins Console Output showing 'Hello World from Jenkins' and Java version. This provides final verification that the 'Execute shell' step ran successfully, outputting teh expected string and confirming the use of OpenJDK 17.*

![Figure 19: The Jenkins Blue Ocean Gui.](/docs/evidence/19-jenkins-blue-ocean-gui.png)
***Figure 19:** The Jenkins Blue Ocean Gui protocols the same console output confirming the successful build.*

---

## 💻 Task 6: Direct Container Access

For advanced troubleshooting or manual configuration of the `/var/jenkins_home` directory the interactive shell can be utilized:

~~~bash
# Entering the Jenkins container environment
docker exec -it jenkins-blueocean bash
~~~

Additionally, Jenkins provides a CLI interface accessible via the `/cli` route, though the Web UI remains the primary interface for this implementation.

---


## 🛠️ Automation with Makefile

To avoid manual errors and simplify the deployment, a Makefile was created to standardize the workflow:

- (1) `make setup`: Starts the engine: Creates the network and starts the `jenkins-docker` engine.
- (2) `make build`: Rebuilds the Jenkins Dockerfile image.
- (3) `make run`:   Starts Jenkins: Deploys the container with all network and volume mappings.
- (4) `make login`  Prints the password to the terminal.
- (5) `make clean`: Removes the container to allow for a fresh start.

### 🛠️ Makefile Troubleshooting Note
During the iteration process, a `make: *** [clean] Error 1` was encountered. This was due to `docker rm` receiving empty arguments when the container variables were not correctly initialized. 

**Refinement:**
The `clean` target was updated with the `|| true` modifier to ensure the build pipeline continues even if containers have already been removed:
~~~bash
clean:
    docker rm -f $(CONT_JENKINS) $(CONT_DOCKER) || true
~~~








 