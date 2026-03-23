# Fixed: Use a modern LTS version
FROM jenkins/jenkins:lts-jdk17

USER root
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli

USER jenkins
# Fixed: Removing specific versions allows the CLI to find the best fit for your Jenkins core 
# + added 'json-path-api' to satisfy the dependency chain for Blue Ocean
RUN jenkins-plugin-cli --plugins "json-path-api blueocean docker-workflow"