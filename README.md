# 🚀 jenkins-dockerized-cicd-platform

A modernized Jenkins CI/CD environment engineered with a **Sidecar (Docker-in-Docker) Architecture**. This platform provides a fully containerized, portable, and automated infrastructure for building and deploying software.

## 🛠️ Key Features
* **Modernized Stack:** Jenkins LTS running on **OpenJDK 17**.
* **Sidecar Engine:** Isolated Docker-in-Docker (DinD) daemon for secure build execution.
* **Automated Lifecycle:** Full environment orchestration via a unified `Makefile`.
* **Persistence:** State-managed configuration using Docker volumes for jobs, users, and plugins.

## 🏗️ Architecture
The platform follows the **Docker-outside-of-Docker (DooD)** pattern, where the Jenkins Controller acts as a client to a dedicated Docker Engine sidecar over a virtual bridge network.

## 📖 Project Documentation
For a deep dive into the engineering process, troubleshooting dependency gaps, and architectural decisions, please refer to the full implementation diary:

👉 **[Detailed Implementation Diary](/docs/IMPLEMENTATION.md)**

## 🚀 Quick Start
To spin up the platform, ensure you have Docker installed and run:

```bash
# 1. Initialize network and Docker engine
make setup

# 2. Build the modernized Jenkins image
make build

# 3. Launch the Jenkins Controller
make run

# 4. Retrieve initial Admin password
make login