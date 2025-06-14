#!/bin/bash

#  _      ______ ____  __  __ _____ _   _
# | |    |  ____/ __ \|  \/  |_   _| \ | |
# | |    | |__ | |  | | \  / | | | |  \| |
# | |    |  __|| |  | | |\/| | | | | . ` |
# | |____| |___| |__| | |  | |_| |_| |\  |
# |______|______\____/|_|  |_|_____|_| \_|
set -e

# --- Configuration ---
USER_NAME="MinhTD"
USER_EMAIL="tranminhsvp@gmail.com"
SSH_KEY_FILE="$HOME/.ssh/id_ed25519"

APT_PACKAGES=(
    "python3"
    "python3-pip"
    "python3-tk"
    "python3-venv"
    "python3-neovim"
    "dotnet-sdk-8.0"
    "ffmpeg"
    "bat"
    "fzf"
    "fd-find"
    "ripgrep"
    "zoxide"
    "vim"
    "kitty"
    "alacritty"
    "mpv"
    "curl"
    "stow"
    "tmux"
    "tldr"
    "btop"
    "neofetch"
    "xclip"
    "ssh-askpass"
    "virt-manager"
    "gnome-keyring"
    # "kdenlive"
)

FLATPAK_PACKAGES=(
    "com.google.Chrome"
    "io.dbeaver.DBeaverCommunity"
    "com.getpostman.Postman"
    "org.telegram.desktop"
    "com.brave.Browser"
    "io.missioncenter.MissionCenter"
    "com.discordapp.Discord"
    "com.stremio.Stremio"
)

# --- Helper Functions ---
log_info() { echo "💬 [$(date '+%H:%M:%S')] $1"; }
log_success() { echo "✅ $1"; }
log_warning() { echo "⚠️ $1"; }
log_error() { echo "❌ $1"; }

is_installed() {
    command -v "$1" &>/dev/null || dpkg -s "$1" &>/dev/null
}

# Install Fastfetch
install_fastfetch() {
    log_info "Adding Fastfetch PPA and installing..."
    sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y &&
        sudo apt update &&
        sudo apt install fastfetch -y &&
        log_success "Fastfetch installed successfully." || log_error "Failed to install Fastfetch."
}

install_software() {
    local name="$1"
    if ! is_installed "$name"; then
        log_info "Installing '$name'..."
        sudo apt install -y "$name" && log_success "Successfully installed '$name'." || log_error "Failed to install '$name'."
    else
        log_info "'$name' is already installed, skipping."
    fi
}

configure_git() {
    log_info "Configuring Git user name and email."
    git config --global user.name "$USER_NAME"
    git config --global user.email "$USER_EMAIL"
    log_success "Git configured."

    if [ ! -f "$SSH_KEY_FILE" ]; then
        log_info "Generating new SSH key..."
        ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$SSH_KEY_FILE" -N ""
        log_success "SSH key generated."
    else
        log_info "SSH key already exists, skipping."
    fi
}

configure_warp() {
    if [ ! -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]; then
        log_info "Adding Cloudflare Warp GPG key..."
        curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg &&
            log_success "Cloudflare Warp GPG key added." || log_error "Failed to add Cloudflare Warp GPG key."
    else
        log_info "Cloudflare Warp GPG key already exists, skipping."
    fi

    local codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    log_info "Adding Cloudflare Warp repository for $codename..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $codename main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null &&
        log_success "Cloudflare Warp repository added." || log_error "Failed to add Cloudflare Warp repository."

    log_info "Updating APT and installing Cloudflare Warp..."
    sudo apt-get update && sudo apt-get install -y cloudflare-warp &&
        log_success "Cloudflare Warp installed." || log_error "Failed to install Cloudflare Warp."

    log_info "Deleting old Warp registration (if any)..."
    warp-cli registration delete || true

    log_info "Registering new Warp..."
    warp-cli registration new &&
        log_success "Warp registered." || log_error "Failed to register Warp."

    log_info "Connecting Warp..."
    warp-cli connect &&
        log_success "Warp connected." || log_error "Failed to connect Warp."
}

clean_apt() {
    log_info "Cleaning up APT..."
    sudo apt autoremove -y && sudo apt clean
    log_success "APT cleanup completed."
}

install_zsh() {
    if ! command -v zsh &>/dev/null; then
        log_info "Installing Zsh..."
        sudo apt install -y zsh && log_success "Zsh installed." || {
            log_error "Failed to install Zsh."
            return 1
        }
    else
        log_info "Zsh is already installed, skipping."
    fi

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &&
            log_success "Oh My Zsh installed." || {
            log_error "Failed to install Oh My Zsh."
            return 1
        }
    else
        log_info "Oh My Zsh is already installed, skipping."
    fi

    local real_user="${SUDO_USER:-$USER}"
    local current_shell
    current_shell="$(getent passwd "$real_user" | cut -d: -f7)"

    if [ "$current_shell" != "$(which zsh)" ]; then
        log_info "Changing default shell to Zsh for user $real_user..."
        sudo chsh -s "$(which zsh)" "$real_user" &&
            log_success "Default shell changed to Zsh (log out to apply)." || log_error "Failed to change default shell to Zsh."
    else
        log_info "Default shell is already Zsh."
    fi
}

install_zsh_plugins() {
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

    declare -A plugins=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
        ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
    )

    for name in "${!plugins[@]}"; do
        local dir="$plugins_dir/$name"
        if [ ! -d "$dir" ]; then
            log_info "Installing Zsh plugin: $name..."
            git clone "${plugins[$name]}" "$dir" && log_success "Plugin '$name' installed." || log_error "Failed to install plugin '$name'."
        else
            log_info "Zsh plugin '$name' is already installed, skipping."
        fi
    done

    log_warning "📌 Add the following plugins to your ~/.zshrc: plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions z docker docker-compose)"
}

config_zsh_plugins() {
    local zshrc="$HOME/.zshrc"
    local desired_plugins="plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions z docker docker-compose)"

    if grep -qE '^plugins=\(.*\)' "$zshrc"; then
        log_info "Updating plugins list in ~/.zshrc..."
        sed -i 's/^plugins=(.*)/'"$desired_plugins"'/' "$zshrc" &&
            log_success "Updated plugins in ~/.zshrc." ||
            log_error "Failed to update plugins in ~/.zshrc."
    else
        log_info "Adding plugins list to ~/.zshrc..."
        echo "$desired_plugins" >>"$zshrc" &&
            log_success "Added plugins to ~/.zshrc." ||
            log_error "Failed to add plugins to ~/.zshrc."
    fi
}

install_nerdfont() {
    mkdir -p ~/.local/share/fonts
    if fc-list | grep -i "JetBrainsMono" &>/dev/null; then
        log_info "JetBrainsMono font is already installed, skipping."
    else
        log_info "Downloading and installing JetBrainsMono font..."
        wget -O ~/.local/share/fonts/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip &&
            cd ~/.local/share/fonts &&
            unzip -o JetBrainsMono.zip &&
            rm JetBrainsMono.zip &&
            fc-cache -fv &&
            log_success "JetBrainsMono font installed successfully." || log_error "Failed to install JetBrainsMono font."
    fi
}

install_docker() {
    if command -v docker &>/dev/null; then
        log_success "Docker is already installed. Skipping installation."
        return
    fi

    log_info "Installing Docker..."

    sudo apt-get update && sudo apt-get install -y ca-certificates curl &&
        log_success "Docker prerequisites installed." || log_error "Failed to install Docker prerequisites."

    sudo install -m 0755 -d /etc/apt/keyrings

    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc &&
        sudo chmod a+r /etc/apt/keyrings/docker.asc &&
        log_success "Docker GPG key added." || log_error "Failed to add Docker GPG key."

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null &&
        log_success "Docker repository added." || log_error "Failed to add Docker repository."

    sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin &&
        log_success "Docker installation completed." || log_error "Failed to install Docker."
}

install_lazydocker() {
    log_info "Starting Lazydocker installation/configuration."

    local current_shell=$(basename "$SHELL")
    local lzd_alias_configured="false"

    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

    local alias_docker_run_cmd="sudo docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v ~/.config/jesseduffield/lazydocker lazyteam/lazydocker"
    local bash_zsh_alias_line="alias lzd='${alias_docker_run_cmd}'"

    if [ "$current_shell" = "zsh" ] || [ "$current_shell" = "bash" ]; then
        log_info "Configuring 'lzd' alias for $current_shell shell."
        local SHELL_CONFIG_FILE
        if [ "$current_shell" = "zsh" ]; then
            SHELL_CONFIG_FILE="$HOME/.zshrc"
        else
            SHELL_CONFIG_FILE="$HOME/.bashrc"
        fi
        if grep -qxF "$bash_zsh_alias_line" "$SHELL_CONFIG_FILE" 2>/dev/null; then
            log_info "Alias 'lzd' already found in $current_shell config file: $SHELL_CONFIG_FILE. Skipping addition."
            lzd_alias_configured="true"
        else
            echo "$bash_zsh_alias_line" >>"$SHELL_CONFIG_FILE"
            log_success "Alias 'lzd' added to $current_shell config: $SHELL_CONFIG_FILE."
            lzd_alias_configured="true"
        fi
    else
        log_warning "Unsupported shell: $current_shell. Cannot automatically configure 'lzd' alias."
    fi

    if [ "$lzd_alias_configured" = "true" ]; then
        log_info "Lazydocker setup is complete. You can now type 'lzd' to run Lazydocker."
        log_info "Please restart your terminal or 'source' your shell config file (e.g., 'source ~/.zshrc') for the 'lzd' command to take effect in this session."
    else
        log_warning "Lazydocker binary is installed, but the 'lzd' alias could not be configured automatically for your shell."
        log_info "You might need to add the following line manually to your shell's config file (e.g., ~/.bashrc, ~/.zshrc):"
        echo "  alias lzd='${alias_docker_run_cmd}'"
        log_info "Then, restart your terminal or 'source' your shell config file."
    fi

    return 0
}

clone_wallpaper() {
    log_info "Cloning wallpaper repository..."
    if [ ! -d "$HOME/Pictures/wallpaper" ]; then
        mkdir -p "$HOME/Pictures"
        git clone --depth=1 https://github.com/Leomin07/wallpaper.git "$HOME/Pictures/wallpaper" &&
            log_success "Wallpaper repository cloned to ~/Pictures/wallpaper." || log_error "Failed to clone wallpaper repository."
    else
        log_info "Wallpaper repository already exists in ~/Pictures/wallpaper, skipping clone."
    fi
}

config_zoxide() {
    local bashrc="$HOME/.bashrc"
    local zshrc="$HOME/.zshrc"

    local bash_init='eval "$(zoxide init bash)"'
    local zsh_init='eval "$(zoxide init zsh)"'

    if [ -f "$bashrc" ] && ! grep -Fxq "$bash_init" "$bashrc"; then
        echo "$bash_init" >>"$bashrc"
        echo "[✔] Added zoxide init to $bashrc"
    else
        echo "[✔] zoxide already configured in $bashrc or file not found"
    fi

    if [ -f "$zshrc" ] && ! grep -Fxq "$zsh_init" "$zshrc"; then
        echo "$zsh_init" >>"$zshrc"
        echo "[✔] Added zoxide init to $zshrc"
    else
        echo "[✔] zoxide already configured in $zshrc or file not found"
    fi
}

install_starship() {
    log_info "Installing Starship prompt..."
    if ! command -v starship &>/dev/null; then
        log_info "Starship not found. Downloading and installing..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y &&
            log_success "Starship installed successfully." || log_error "Failed to install Starship."
    else
        log_info "Starship is already installed. Skipping installation."
    fi

    add_starship_init() {
        local shell_rc="$1"
        local shell_name="$2"
        local init_cmd="eval \"\$(starship init $shell_name)\""
        if ! grep -Fxq "$init_cmd" "$shell_rc"; then
            echo "$init_cmd" >>"$shell_rc"
            log_info "Added Starship init to $shell_rc"
        else
            log_info "Starship init already exists in $shell_rc. Skipping."
        fi
    }

    [ -f ~/.bashrc ] && add_starship_init ~/.bashrc bash
    [ -f ~/.zshrc ] && add_starship_init ~/.zshrc zsh
}

install_vscode() {
    if command -v code >/dev/null 2>&1; then
        log_info "VSCode is already installed. Checking for updates..."
        sudo apt update
        sudo apt install --only-upgrade -y code
        log_success "VSCode is already installed and has been updated if a new version was available."
        return 0
    fi

    log_info "Import Microsoft GPG key..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    rm -f packages.microsoft.gpg

    log_info "Adding VSCode repository..."
    sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

    log_info "Updating apt and installing code..."
    sudo apt update
    sudo apt install -y code gnome-keyring

    log_success "VSCode installed. Run 'code' to start."
}

configure_fcitx5() {
    log_info "Configuring fcitx5 (Vietnamese input method)..."

    local fcitx5_packages=(fcitx5 fcitx5-frontend-gtk3 fcitx5-configtool fcitx5-bamboo)
    for pkg in "${fcitx5_packages[@]}"; do install_software "$pkg"; done

    local env_vars=(
        'GTK_IM_MODULE=fcitx5'
        'QT_IM_MODULE=fcitx5'
        'XMODIFIERS="@im=fcitx5"'
    )

    add_env_if_missing() {
        local file=$1
        local var_name
        for env in "${env_vars[@]}"; do
            var_name="${env%%=*}"
            if ! grep -qE "^\s*export\s+$var_name=" "$file" 2>/dev/null; then
                echo "export $env" >>"$file"
                log_info "Added export $env to $file"
            else
                log_info "$var_name already set in $file, skipping..."
            fi
        done
    }

    local BASH_FILE="$HOME/.bashrc"
    log_info "Checking Bash config: $BASH_FILE"
    add_env_if_missing "$BASH_FILE"

    local BASH_PROFILE="$HOME/.bash_profile"
    grep -q '[[ -f ~/.bashrc ]] && source ~/.bashrc' "$BASH_PROFILE" 2>/dev/null || echo '[[ -f ~/.bashrc ]] && source ~/.bashrc' >>"$BASH_PROFILE"

    local ZSH_FILE="$HOME/.zshrc"
    log_info "Checking Zsh config: $ZSH_FILE"
    add_env_if_missing "$ZSH_FILE"

    local ZSH_PROFILE="$HOME/.zprofile"
    grep -q '[[ -f ~/.zshrc ]] && source ~/.zshrc' "$ZSH_PROFILE" 2>/dev/null || echo '[[ -f ~/.zshrc ]] && source ~/.zshrc' >>"$ZSH_PROFILE"

    log_success "Fcitx5 environment variables configured."
    echo "➡️  Please restart your graphical session or reboot for the changes to take effect."
}

sync_keybindings() {
    chmod +x map-key.desktop
    chmod +x .Xmodmap
    xmodmap ~/linux-mint/.Xmodmap
    cp ~/linux-mint/map-key.desktop ~/.config/autostart
    log_info "Loading custom keybindings configuration..."
    dconf load /org/cinnamon/desktop/keybindings/ <~/linux-mint/keybindings_config.dconf
    sudo apt-get install simplescreenrecorder

}

install_nodejs() {
    # Install NVM (Node Version Manager)
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

    # Source NVM to make it available in the current shell session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install the latest LTS version of Node.js
    nvm install --lts

    # Install Yarn globally using npm
    npm install --global yarn
}

install_neovim() {
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

    if ! grep -Fxq 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' ~/.zshrc; then
        echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >>~/.zshrc
    fi

    # Add Neovim to PATH in .zshrc if not already present
    if ! grep -Fxq 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' ~/.zshrc; then
        echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >>~/.zshrc
        echo "[INFO] Added Neovim to PATH in ~/.zshrc"
    else
        echo "[INFO] Neovim PATH already exists in ~/.zshrc, skipping."
    fi

    echo "[SUCCESS] Neovim v0.11 has been installed to /opt/nvim-linux-x86_64."
}

# --- Main ---

log_info "Updating APT packages list..."
sudo apt update || log_error "Failed to update APT packages list."

if ! command -v flatpak &>/dev/null; then
    log_info "Installing Flatpak..."
    sudo apt install -y flatpak &&
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &&
        log_success "Flatpak installed and Flathub added." || log_error "Failed to install Flatpak or add Flathub."
else
    log_info "Flatpak is already installed, skipping."
fi

for pkg in "${APT_PACKAGES[@]}"; do
    install_software "$pkg"
done

for flatpak_pkg in "${FLATPAK_PACKAGES[@]}"; do
    if ! flatpak list --app | grep -q "$flatpak_pkg"; then
        log_info "Installing Flatpak app: $flatpak_pkg"
        flatpak install -y flathub "$flatpak_pkg" &&
            log_success "Flatpak app '$flatpak_pkg' installed." || log_error "Failed to install Flatpak app '$flatpak_pkg'."
    else
        log_info "Flatpak app '$flatpak_pkg' is already installed, skipping."
    fi
done

configure_git
install_zsh
install_zsh_plugins
config_zsh_plugins
install_starship
config_zoxide
install_vscode

read -p "Do you want to install Neovim? (y/n): " install_neovim_answer
[[ "$install_neovim_answer" =~ ^[Yy]$ ]] && install_neovim || log_info "Skipping Neovim installation."

read -p "Do you want to install NodeJS? (y/n): " install_nodejs_answer
[[ "$install_nodejs_answer" =~ ^[Yy]$ ]] && install_nodejs || log_info "Skipping NodeJS installation."

read -p "Do you want to install Fastfetch? (y/n): " install_fastfetch_answer
[[ "$install_fastfetch_answer" =~ ^[Yy]$ ]] && install_fastfetch || log_info "Skipping Fastfetch installation."

read -p "Do you want to install Docker? (y/n): " docker_answer
[[ "$docker_answer" =~ ^[Yy]$ ]] && install_docker || log_info "Skipping Docker installation."

read -p "Do you want to install Lazydocker? (y/n): " install_lazydocker_answer
[[ "$install_lazydocker_answer" =~ ^[Yy]$ ]] && install_lazydocker || log_info "Skipping Lazydocker installation."

read -p "Do you want to install Warp? (y/n): " warp_answer
[[ "$warp_answer" =~ ^[Yy]$ ]] && configure_warp || log_info "Skipping Warp installation."

read -p "Do you want to install Nerd Font (JetBrainsMono)? (y/n): " font_answer
[[ "$font_answer" =~ ^[Yy]$ ]] && install_nerdfont || log_info "Skipping font installation."

read -p "Do you want to configure fcitx5 for Vietnamese typing? (y/n): " configure_fcitx5_answer
[[ "$configure_fcitx5_answer" =~ ^[Yy]$ ]] && configure_fcitx5 || log_info "Skipping fcitx5 configuration."

read -p "Do you want to clone the wallpaper repository? (y/n): " clone_answer
if [[ "$clone_answer" =~ ^[Yy]$ ]]; then
    clone_wallpaper
else
    log_info "Skipping wallpaper cloning step."
fi

read -p "Do you want to load custom keybindings config and map key? (y/n): " sync_keybindings_answer
[[ "$sync_keybindings_answer" =~ ^[Yy]$ ]] && sync_keybindings || log_info "Skipping custom keybindings configuration."

clean_apt

log_success "🎉 Environment setup completed!"
