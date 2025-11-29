#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
else
  . /usr/lib/os-release
fi

TARGET_USER="${TARGET_USER:-${SUDO_USER:-$(whoami)}}"
TARGET_HOME="${TARGET_HOME:-/home/$TARGET_USER}"

apt-get -qy update
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade

CLI_PACKAGES=(curl wget git tmux)
DEV_PACKAGES=(build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev)
EDITORS=(micro)

curl_with_retry() {
  local retries=3
  local count=0
  local success=false
  while [ $count -lt $retries ]; do
    if curl "$@"; then
      success=true
      break
    fi
    count=$((count + 1))
    echo "curl failed, retrying ($count/$retries)..." >&2
    sleep 2
  done
  if [ "$success" = false ]; then
    return 1
  fi
}

install_list() {
  local -a list=("$@")
  if [[ "${#list[@]}" -gt 0 ]]; then
    apt-get -qy install "${list[@]}"
  fi
}

install_list "${CLI_PACKAGES[@]}"
install_list "${DEV_PACKAGES[@]}"
install_list "${EDITORS[@]}"

install -m 0755 -d /etc/apt/keyrings
curl_with_retry -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

DOCKER_DIST="ubuntu"
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-stable}}"

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DOCKER_DIST} ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

install -m 0755 -d /usr/share/keyrings
NVIDIA_INSTALL_SUCCESS=true
if [ ! -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]; then
  if ! curl_with_retry -fsSL https://nvidia.github.io/libnvidia-container/gpgkey -o /tmp/nvidia.pub; then
    echo "Warning: Failed to download NVIDIA GPG key. Skipping NVIDIA Container Toolkit installation." >&2
    NVIDIA_INSTALL_SUCCESS=false
  else
    gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg < /tmp/nvidia.pub
    rm -f /tmp/nvidia.pub
  fi
fi

if [ "$NVIDIA_INSTALL_SUCCESS" = true ]; then
  if ! curl_with_retry -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list -o /tmp/nvidia.list; then
    echo "Warning: Failed to download NVIDIA repo list. Skipping NVIDIA Container Toolkit installation." >&2
    NVIDIA_INSTALL_SUCCESS=false
    # Remove potentially stale list file to avoid apt-get update failure
    rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
  else
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' /tmp/nvidia.list \
      | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
    rm -f /tmp/nvidia.list
  fi
fi

apt-get -qy update

DOCKER=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
install_list "${DOCKER[@]}"

if [ "$NVIDIA_INSTALL_SUCCESS" = true ]; then
  apt-get -qy install nvidia-container-toolkit || echo "Warning: Failed to install nvidia-container-toolkit" >&2
fi

if id -u "${TARGET_USER}" >/dev/null 2>&1; then
  usermod -aG docker "${TARGET_USER}" || true
fi

systemctl enable --now docker.service
systemctl enable --now containerd.service

ARCH="$(dpkg --print-architecture)"
mkdir -p "${TARGET_HOME}/.docker/cli-plugins"
MCP_URL="https://github.com/docker/mcp-gateway/releases/download/v0.20.0/docker-mcp-linux-${ARCH}.tar.gz"
wget -O /tmp/docker-mcp.tar.gz "${MCP_URL}" || true
if [[ -s /tmp/docker-mcp.tar.gz ]]; then
  tar -xzf /tmp/docker-mcp.tar.gz -C /tmp || true
  if [[ -x /tmp/docker-mcp ]]; then
    install -m 0755 /tmp/docker-mcp "${TARGET_HOME}/.docker/cli-plugins/docker-mcp"
    chown "${TARGET_USER}":"${TARGET_USER}" "${TARGET_HOME}/.docker/cli-plugins/docker-mcp"
  fi
fi

if [ ! -d "${TARGET_HOME}/.asdf" ]; then
  sudo -u "$TARGET_USER" bash -c 'git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.15.0'
fi

sudo -u "$TARGET_USER" bash -c 'grep -qxF '\''
. $HOME/.asdf/asdf.sh'\'' ~/.bashrc || echo -e "\n. $HOME/.asdf/asdf.sh" >> ~/.bashrc'
sudo -u "$TARGET_USER" bash -c 'grep -qxF '\''
. $HOME/.asdf/completions/asdf.bash'\'' ~/.bashrc || echo -e "\n. $HOME/.asdf/completions/asdf.bash" >> ~/.bashrc'

sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git || true'
sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && asdf plugin-add java https://github.com/halcyon/asdf-java.git || true'
sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && asdf plugin-add python || true'

sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && asdf install nodejs latest || true'
sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && asdf install java openjdk-21 || true'
sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && asdf install python latest || true'
sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && asdf global nodejs latest'
sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && asdf global java openjdk-21'
sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && asdf global python latest'
sudo -u "$TARGET_USER" bash -c '. ~/.asdf/asdf.sh && pip install uv pipx'

echo "========================================================================"
echo " Setup complete!"
echo " Please restart your shell or run the following command to start using asdf:"
echo " source ~/.bashrc"
echo "========================================================================"
