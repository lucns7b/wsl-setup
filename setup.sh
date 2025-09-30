#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
else
  . /usr/lib/os-release
fi

echo "Rodando em: ${PRETTY_NAME:-Linux}"

# Detecta usuário para instalar lazydocker no home correto
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(eval echo "~$TARGET_USER")"

if [[ "${ID:-}" = "debian" ]] || [[ "${ID:-}" = "ubuntu" ]] || [[ "${ID_LIKE:-}" == *debian* ]]; then
  export DEBIAN_FRONTEND=noninteractive

  apt-get -qy update
  apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade

  CLI_PACKAGES=(ca-certificates curl wget git zip unzip htop tmux)
  DEV_PACKAGES=(build-essential openjdk-21-jre)
  LANG_PACKAGES=(nodejs npm)
  EDITORS=(nano micro)

  install_list() {
    local -a list=("$@")
    if [[ "${#list[@]}" -gt 0 ]]; then
      apt-get -qy install "${list[@]}"
    fi
  }

  install_list "${CLI_PACKAGES[@]}"
  install_list "${DEV_PACKAGES[@]}"
  install_list "${LANG_PACKAGES[@]}"
  install_list "${EDITORS[@]}"

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  DOCKER_DIST="ubuntu"
  CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-stable}}"
  if [[ "${ID:-}" = "debian" ]]; then
    DOCKER_DIST="debian"
    CODENAME="${VERSION_CODENAME:-stable}"
  fi

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DOCKER_DIST} ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

  install -m 0755 -d /usr/share/keyrings
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

  apt-get -qy update

  DOCKER=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
  install_list "${DOCKER[@]}"
  apt-get -qy install nvidia-container-toolkit

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

  # Instala uv
  sudo -u "$TARGET_USER" bash -c 'curl -fsSL https://astral.sh/uv/install.sh | bash'
  # Copia uv e uvx para /usr/local/bin se existirem
  if [[ -f "${TARGET_HOME}/.local/bin/uv" ]]; then
    cp -f "${TARGET_HOME}/.local/bin/uv" /usr/local/bin/
    chmod +x /usr/local/bin/uv
  fi
  if [[ -f "${TARGET_HOME}/.local/bin/uvx" ]]; then
    cp -f "${TARGET_HOME}/.local/bin/uvx" /usr/local/bin/
    chmod +x /usr/local/bin/uvx
  fi

  # Instalação lazydocker NO USUÁRIO CORRETO
  sudo -u "$TARGET_USER" bash -c \
    'curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash'
  
  # Também torna global diretamente (garantido):
  if [[ -f "${TARGET_HOME}/.local/bin/lazydocker" ]]; then
    cp -f "${TARGET_HOME}/.local/bin/lazydocker" /usr/local/bin/
    chmod +x /usr/local/bin/lazydocker
  fi

  # pipx: garantir PATH no profile do usuário correto
  if ! grep -qF "${TARGET_HOME}/.local/bin" "${TARGET_HOME}/.profile" ; then
    echo 'export PATH=$PATH:$HOME/.local/bin' >> "${TARGET_HOME}/.profile"
  fi

  pipx ensurepath || true

  # Cloudflare Tunnel
  mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  
  echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
  
  # install cloudflared
  apt-get -qy update
  apt-get -qy install cloudflared
  

  # Instalação DUC-NOIP Client
  wget --content-disposition https://www.noip.com/download/linux/latest
  tar xf noip-duc_3.3.0.tar.gz
  cd /home/$USER/noip-duc_3.3.0/binaries && apt install -y ./noip-duc_3.3.0_amd64.deb
  # Para dispositivos ARM64: apt install -y ./noip-duc_3.3.0_arm64.deb
  
  # Arquivo de configuração do DUC
  tee /etc/default/noip-duc <<EOF
## File: /etc/default/noip-duc
NOIP_USERNAME=
NOIP_PASSWORD=eMbAE17W2PHQ
NOIP_HOSTNAMES=
EOF
  
  cat /etc/default/noip-duc
  
  # Configurando inicialização com o sistema
  systemctl daemon-reload
  systemctl enable noip-duc
  systemctl start noip-duc

  echo "Instalações adicionais concluídas em Debian/Ubuntu."
else
  echo "Este script é para Debian/Ubuntu."
  exit 1
fi
