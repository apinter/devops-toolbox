## DevOps toolbox build
FROM registry.opensuse.org/opensuse/tumbleweed:latest

## Add a custom Ansible config and collections/roles requirements
COPY config/ansible.cfg /ansible.cfg
COPY config/requirements.yml /requirements.yml
COPY config/mongo.repo /etc/zypp/repos.d/repo-mongo.repo

## Update os and install reuired packages
RUN zypper addrepo https://cli.github.com/packages/rpm/gh-cli.repo && \
  curl -L -o /tmp/gh.key "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x23F3D4EA75716059" && \
  rpm --import /tmp/gh.key && \
  rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
  zypper addrepo --name 'Azure CLI' --check https://packages.microsoft.com/yumrepos/azure-cli azure-cli

RUN zypper ref && zypper dup -y
RUN zypper in -y fish \
  zsh \
  just \
  unzip\
  kubernetes-client \
  python3 \
  python3-devel \
  python3-pip \
  openssh-clients \
  git \
  openssl \
  buildah \
  curl \
  wget \
  helm \
  sshpass \
  vim \
  nano \
  nginx \
  htop \
  jq \
  bat && \
  mongodb-org-tools && \
  mongodb-mongosh && \
  postgresql15 && \
  mariadb-client && \
  zypper clean -a && \
  zypper in -y --from azure-cli azure-cli

RUN python3 -m venv /devops && /devops/bin/python3 -m pip install ansible \
    ansible-vault \
    ara \
    openshift \
    yamllint \
    glances \
    linode-cli \
    boto3 \
    botocore

## Install k9s
RUN curl -L https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz -o /tmp/k9s_Linux_x86_64.tar.gz && \
  cd /tmp && tar xzvf k9s_Linux_x86_64.tar.gz && \
  install -D -p -m 0755 k9s /usr/bin/k9s && \
  rm k9s_Linux_x86_64.tar.gz && rm k9s

## Add the Hashicorp repo and install Terraform
RUN mkdir tf && cd tf && curl -LO https://releases.hashicorp.com/terraform/1.6.3/terraform_1.6.3_SHA256SUMS && \
  curl -LO https://releases.hashicorp.com/terraform/1.6.3/terraform_1.6.3_SHA256SUMS.sig && \
  curl -LO https://releases.hashicorp.com/terraform/1.6.3/terraform_1.6.3_linux_amd64.zip && \
  curl -L -o tf-pgp.key https://www.hashicorp.com/.well-known/pgp-key.txt && \
  gpg --import tf-pgp.key && \
  gpg --verify terraform_1.6.3_SHA256SUMS.sig terraform_1.6.3_SHA256SUMS && \
  sha256sum -c terraform_1.6.3_SHA256SUMS 2>&1 | grep OK && \
  unzip terraform_1.6.3_linux_amd64.zip && \
  install -D -p -m 0755 terraform /usr/bin/terraform && \
  cd .. && rm -rf /tmp/tf

## Install ansible reuired collections and roles
RUN /devops/bin/ansible-galaxy collection install -r requirements.yml

## Install yq
RUN wget https://github.com/mikefarah/yq/releases/download/v4.35.2/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq

## Install gcloud
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-453.0.0-linux-x86_64.tar.gz && \
  tar -xf google-cloud-cli-453.0.0-linux-x86_64.tar.gz && \
  rm google-cloud-cli-453.0.0-linux-x86_64.tar.gz && \
  ./google-cloud-sdk/install.sh && \
  source /google-cloud-sdk/completion.bash.inc && \
  source /google-cloud-sdk/path.bash.inc && \
  gcloud components install gke-gcloud-auth-plugin
RUN echo -e 'source /google-cloud-sdk/completion.bash.inc\nsource /google-cloud-sdk/path.bash.inc' > /etc/profile.d/gcp.sh 

## Install eksctl
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp && \
  install -D -p -m 0755 /tmp/eksctl /usr/bin/eksctl

## Install aws cli
RUN cd /tmp && curl --silent "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip awscliv2.zip && \
  ./aws/install

## Ansible and ARA configuration
ENV ANSIBLE_CONFIG=/ansible.cfg
ENV ANSIBLE_CALLBACK_PLUGINS="$(/devops/bin/python3 -m ara.setup.callback_plugins)"
ENV ARA_API_CLIENT=http
ENV ARA_API_SERVER="https://ara.openstorage.xyz"
ENV ARA_API_USERNAME=araosc

RUN /devops/bin/python3 -m ara.setup.path
RUN /devops/bin/python3 -m ara.setup.plugins
RUN /devops/bin/python3 -m ara.setup.action_plugins
RUN /devops/bin/python3 -m ara.setup.callback_plugins
RUN /devops/bin/python3 -m ara.setup.env
RUN /devops/bin/python3 -m ara.setup.ansible
