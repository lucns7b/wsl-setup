# 🦾 WSL Setup Automático | Debian/Ubuntu 💻 

Automatização do ambiente **WSL (Windows Subsystem for Linux)**  
Script Bash completo para instalar pacotes essenciais, preparar Docker, NVIDIA Container Toolkit, pipx, uv, lazydocker e etc... 🎉

---

## 🚀 Execução Instantânea

```

curl -fsSL https://raw.githubusercontent.com/lucns7b/wsl-setup/main/setup.sh | sudo bash

```
> _⚡ SEMPRE Revisar o script antes de executar_

---

## ✨ Principais Recursos

- 🚦 Detecta automaticamente sua distribuição (Debian/Ubuntu)
- 🔗 Repositórios modernos usando keyrings (`signed-by`)
- 📦 Instala blocos de pacotes essenciais para devs
- 🐋 Prepara Docker e plugins (buildx, compose etc)
- 👤 Adiciona o usuário ao grupo docker (exige relogar)
- 🟩 Instala NVIDIA Container Toolkit (GPU ready WSL2)
- 🤖 Instala pipx, uv, lazydocker e utilitários extras

---

## 💡 Como usar

1. **Execute o 1-liner acima**
2. **Relogue sua sessão do Linux/WSL** para aplicar grupo Docker
3. **Teste:**
    - `docker --version`
    - `docker run hello-world`
    - `nvidia-ctk --version` (se tiver GPU Nvidia/WSL2 GPU)

---

## 🧠 Dicas rápidas

- Compatível com Ubuntu/Debian no WSL, testado em Ubuntu 22.04+, Debian 12+  
- URLs/plugins podem variar conforme arquitetura do seu WSL (ex: arm64 vs amd64)
- Recomenda-se rodar como root/sudo para instalar pacotes do sistema
- Use sempre `apt-get -qy` para automação 100%
- Após rodar, sempre relogue (logout/login ou reinicie o terminal)

---

## 📄 Licença

MIT License.  
Livre pra usar, modificar e compartilhar! 🫶

---

*Transforme seu WSL em um ambiente turbinado em minutos.  
Automação é liberdade. Sinta o poder do terminal!*  
