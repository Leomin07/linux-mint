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

# Fish shell path and config file
FISH_SHELL="/usr/bin/fish"
FISH_CONFIG_DIR="$HOME/.config/fish"
FISH_CONFIG_FILE="$FISH_CONFIG_DIR/config.fish"

FISH_PLUGINS=(
    "gazorby/fish-abbreviation-tips"
    "jhillyerd/plugin-git"
    "jethrokuan/z"
    "jorgebucaran/autopair.fish"
)

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
    "zoxide"
    "vim"
    "neovim"
    "kitty"
    "alacritty"
    "mpv"
    "curl"
    "stow"
    "tmux"
    "fish"
    "btop"
    "neofetch"
    "kdenlive"
    "code"
)

FLATPAK_PACKAGES=(
    "com.google.Chrome"
    "io.dbeaver.DBeaverCommunity"
    "com.getpostman.Postman"
    "org.telegram.desktop"
    "com.brave.Browser"
    "io.missioncenter.MissionCenter"
    "com.discordapp.Discord"
)

# --- Helper Functions ---
log_info() { echo "💬 [$(date '+%H:%M:%S')] $1"; }
log_success() { echo "✅ $1"; }
log_warning() { echo "⚠️ $1"; }
log_error() { echo "❌ $1"; } # Added for error messages

is_installed() {
    command -v "$1" &>/dev/null || dpkg -s "$1" &>/dev/null
}

# Install Fastfetch
install_fastfetch(){
    log_info "Adding Fastfetch PPA and installing..."
    sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y && \
    sudo apt update && \
    sudo apt install fastfetch -y && \
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
    # Add Cloudflare GPG key if it doesn't exist
    if [ ! -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]; then
        log_info "Adding Cloudflare Warp GPG key..."
        # Note: The GPG key might require specific permissions or a different path
        # depending on your apt configuration.
        curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
        log_success "Cloudflare Warp GPG key added." || log_error "Failed to add Cloudflare Warp GPG key."
    else
        log_info "Cloudflare Warp GPG key already exists, skipping."
    fi

    # Add this repo to your apt repositories
    local codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    log_info "Adding Cloudflare Warp repository for $codename..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $codename main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null && \
    log_success "Cloudflare Warp repository added." || log_error "Failed to add Cloudflare Warp repository."

    # Update and install
    log_info "Updating APT and installing Cloudflare Warp..."
    sudo apt-get update && sudo apt-get install -y cloudflare-warp && \
    log_success "Cloudflare Warp installed." || log_error "Failed to install Cloudflare Warp."

    # Delete old registration if it exists
    log_info "Deleting old Warp registration (if any)..."
    warp-cli registration delete || true # '|| true' to prevent script from exiting if delete fails

    # Register and connect Warp
    log_info "Registering new Warp..."
    warp-cli registration new && \
    log_success "Warp registered." || log_error "Failed to register Warp."

    log_info "Connecting Warp..."
    warp-cli connect && \
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
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
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
        sudo chsh -s "$(which zsh)" "$real_user" && \
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
        sed -i 's/^plugins=(.*)/'"$desired_plugins"'/' "$zshrc" && \
        log_success "Updated plugins in ~/.zshrc." || \
        log_error "Failed to update plugins in ~/.zshrc."
    else
        log_info "Adding plugins list to ~/.zshrc..."
        echo "$desired_plugins" >> "$zshrc" && \
        log_success "Added plugins to ~/.zshrc." || \
        log_error "Failed to add plugins to ~/.zshrc."
    fi
}


install_nerdfont() {
    mkdir -p ~/.local/share/fonts
    if fc-list | grep -i "JetBrainsMono" &>/dev/null; then
        log_info "JetBrainsMono font is already installed, skipping."
    else
        log_info "Downloading and installing JetBrainsMono font..."
        wget -O ~/.local/share/fonts/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip && \
        cd ~/.local/share/fonts && \
        unzip -o JetBrainsMono.zip && \
        rm JetBrainsMono.zip && \
        fc-cache -fv && \
        log_success "JetBrainsMono font installed successfully." || log_error "Failed to install JetBrainsMono font."
    fi
}

install_docker() {
    if command -v docker &>/dev/null; then
        log_success "Docker is already installed. Skipping installation."
        return
    fi

    log_info "Installing Docker..."

    # Update and install necessary packages
    sudo apt-get update && sudo apt-get install -y ca-certificates curl && \
    log_success "Docker prerequisites installed." || log_error "Failed to install Docker prerequisites."

    # Create keyrings directory if it doesn't exist
    sudo install -m 0755 -d /etc/apt/keyrings

    # Download and set permissions for Docker GPG key
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    sudo chmod a+r /etc/apt/keyrings/docker.asc && \
    log_success "Docker GPG key added." || log_error "Failed to add Docker GPG key."

    # Add Docker repository to sources list
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null && \
    log_success "Docker repository added." || log_error "Failed to add Docker repository."

    # Update and install Docker
    sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    log_success "Docker installation completed." || log_error "Failed to install Docker."
}

set_default_shell() {
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    if [ "$current_shell" != "$FISH_SHELL" ]; then
        log_info "Changing default shell to fish for user $USER..."
        sudo chsh -s "$FISH_SHELL" "$USER" && \
        log_success "Default shell changed to Fish (log out to apply)." || log_error "Failed to change default shell to Fish."
    else
        log_info "Default shell is already fish."
    fi
}

install_fisher() {
    if ! fish -c "type -q fisher"; then
        log_info "Installing Fisher (Fish plugin manager)..."
        fish -c 'curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher' && \
        log_success "Fisher installed." || log_error "Failed to install Fisher."
    else
        log_info "Fisher is already installed, skipping."
    fi
}

install_fish_plugins() {
    log_info "Installing Fish plugins..."
    for plugin in "${FISH_PLUGINS[@]}"; do
        if ! fish -c "fisher list | grep -q '$plugin'"; then
            log_info "Installing Fish plugin: $plugin"
            fish -c "fisher install $plugin" && \
            log_success "Fish plugin '$plugin' installed." || log_error "Failed to install Fish plugin '$plugin'."
        else
            log_info "Fish plugin '$plugin' is already installed."
        fi
    done
}


# install_lazydocker() {
#     log_info "Installing Lazydocker..."
#     curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash && \
#     log_success "Lazydocker installed." || log_error "Failed to install Lazydocker."

#     # Create config directory if not exists
#     mkdir -p "$FISH_CONFIG_DIR"

#     # Alias for LazyDocker using container
#     local alias_line="alias lzd='sudo docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v ~/.config/jesseduffield/lazydocker lazyteam/lazydocker'"

#     # Avoid adding duplicates
#     grep -qxF "$alias_line" "$FISH_CONFIG_FILE" || echo "$alias_line" >>"$FISH_CONFIG_FILE"
#     log_success "Alias for LazyDocker added to Fish config."
# }


install_lazydocker() {
    log_info "Starting Lazydocker installation/configuration."

    local current_shell=$(basename "$SHELL")
    local lazydocker_binary_found="false"
    local lzd_alias_configured="false" # Tracks if the alias was successfully added/found in the config file

    # --- 1. Check if Lazydocker binary is already installed ---
    if command -v lazydocker >/dev/null 2>&1; then
        log_info "Lazydocker binary already found in PATH. Skipping direct installation."
        lazydocker_binary_found="true"
    else
        log_info "Lazydocker binary not found. Attempting installation from jesseduffield/lazydocker script."
        curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
        local install_status=$? # Capture the exit status of the curl|bash pipeline
        
        if [ $install_status -eq 0 ] && command -v lazydocker >/dev/null 2>&1; then
            log_success "Lazydocker binary installed successfully."
            lazydocker_binary_found="true"
        else
            log_error "Failed to install Lazydocker binary. Please ensure Docker is running and you have necessary permissions."
        fi
    fi

    # Exit early if binary installation failed and no binary is found
    if [ "$lazydocker_binary_found" = "false" ]; then
        log_error "Lazydocker binary is not available. Cannot proceed with alias configuration."
        return 1 # Indicate failure
    fi

    # --- 2. Check and configure alias for the current shell ---
    # Prepare alias content based on shell type
    local alias_docker_run_cmd="sudo docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v ~/.config/jesseduffield/lazydocker lazyteam/lazydocker"
    local fish_alias_content="function lzd\n  ${alias_docker_run_cmd}\nend"
    local bash_zsh_alias_line="alias lzd='${alias_docker_run_cmd}'"

    if [ "$current_shell" = "fish" ]; then
        log_info "Configuring 'lzd' alias for Fish shell."
        local FISH_FUNCTIONS_DIR="$HOME/.config/fish/functions"
        local FISH_CONFIG_FILE="$FISH_FUNCTIONS_DIR/lzd.fish"

        mkdir -p "$FISH_FUNCTIONS_DIR" # Ensure directory exists

        if grep -qxF "$fish_alias_content" "$FISH_CONFIG_FILE"; then
            log_info "Alias 'lzd' already found in Fish config file: $FISH_CONFIG_FILE. Skipping addition."
            lzd_alias_configured="true"
        else
            echo "$fish_alias_content" > "$FISH_CONFIG_FILE" # Overwrite/create new file for the function
            log_success "Alias 'lzd' added to Fish config: $FISH_CONFIG_FILE."
            lzd_alias_configured="true"
        fi

    elif [ "$current_shell" = "zsh" ] || [ "$current_shell" = "bash" ]; then
        log_info "Configuring 'lzd' alias for $current_shell shell."
        local SHELL_CONFIG_FILE # Dynamic assignment
        if [ "$current_shell" = "zsh" ]; then
            SHELL_CONFIG_FILE="$HOME/.zshrc"
        else
            SHELL_CONFIG_FILE="$HOME/.bashrc"
        fi

        if grep -qxF "$bash_zsh_alias_line" "$SHELL_CONFIG_FILE"; then
            log_info "Alias 'lzd' already found in $current_shell config file: $SHELL_CONFIG_FILE. Skipping addition."
            lzd_alias_configured="true"
        else
            echo "$bash_zsh_alias_line" >> "$SHELL_CONFIG_FILE"
            log_success "Alias 'lzd' added to $current_shell config: $SHELL_CONFIG_FILE."
            lzd_alias_configured="true"
        fi
    else
        log_warning "Unsupported shell: $current_shell. Cannot automatically configure 'lzd' alias."
    fi

    # --- Final instructions ---
    if [ "$lzd_alias_configured" = "true" ]; then
        log_info "Lazydocker setup is complete. You can now type 'lzd' to run Lazydocker."
        log_info "Please restart your terminal or 'source' your shell config file (e.g., 'source ~/.zshrc') for the 'lzd' command to take effect in this session."
    else
        log_warning "Lazydocker binary is installed, but the 'lzd' alias could not be configured automatically for your shell."
        log_info "You might need to add the following line manually to your shell's config file (e.g., ~/.bashrc, ~/.zshrc, or ~/.config/fish/functions/lzd.fish):"
        if [ "$current_shell" = "fish" ]; then
            echo "  function lzd; ${alias_docker_run_cmd}; end"
        else
            echo "  alias lzd='${alias_docker_run_cmd}'"
        fi
        log_info "Then, restart your terminal or 'source' your shell config file."
    fi

    return 0 # Indicate success of the function
}


clone_wallpaper() {
    log_info "Cloning wallpaper repository..."
    if [ ! -d "~/Pictures/wallpaper" ]; then # Check if directory exists before cloning
        cd ~/Pictures # You can also choose a different location
        git clone --depth=1 https://github.com/Leomin07/wallpaper.git ~/Pictures/wallpaper && \
        log_success "Wallpaper repository cloned to ~/Pictures/wallpaper." || log_error "Failed to clone wallpaper repository."
    else
        log_info "Wallpaper repository already exists in ~/Pictures/wallpaper, skipping clone."
    fi
}

config_zoxide() {
    local bashrc="$HOME/.bashrc"
    local zshrc="$HOME/.zshrc"
    local fish_config="$HOME/.config/fish/config.fish"

    local bash_init='eval "$(zoxide init bash)"'
    local zsh_init='eval "$(zoxide init zsh)"'
    local fish_init='zoxide init fish | source'

    # Add to Bash config
    if [ -f "$bashrc" ] && ! grep -Fxq "$bash_init" "$bashrc"; then
        echo "$bash_init" >> "$bashrc"
        echo "[✔] Added zoxide init to $bashrc"
    else
        echo "[✔] zoxide already configured in $bashrc or file not found"
    fi

    # Add to Zsh config
    if [ -f "$zshrc" ] && ! grep -Fxq "$zsh_init" "$zshrc"; then
        echo "$zsh_init" >> "$zshrc"
        echo "[✔] Added zoxide init to $zshrc"
    else
        echo "[✔] zoxide already configured in $zshrc or file not found"
    fi

    # Add to Fish config
    # if [ -f "$fish_config" ] && ! grep -Fxq "$fish_init" "$fish_config"; then
    #     echo "$fish_init" >> "$fish_config"
    #     echo "[✔] Added zoxide init to $fish_config"
    # else
    #     echo "[✔] zoxide already configured in $fish_config or file not found"
    # fi
}



install_starship() {
    log_info "Installing Starship prompt..."

    # Install Starship if not already installed
    if ! command -v starship &>/dev/null; then
        log_info "Starship not found. Downloading and installing..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y && \
        log_success "Starship installed successfully." || log_error "Failed to install Starship."
    else
        log_info "Starship is already installed. Skipping installation."
    fi

    # Function to append init command if not already present
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

    # Configure for bash
    [ -f ~/.bashrc ] && add_starship_init ~/.bashrc bash

    # Configure for zsh
    [ -f ~/.zshrc ] && add_starship_init ~/.zshrc zsh

    # Configure for fish
    # fish_config="$HOME/.config/fish/config.fish"
    # fish_init_cmd='starship init fish | source'
    # mkdir -p "$(dirname "$fish_config")"
    # if ! grep -Fxq "$fish_init_cmd" "$fish_config"; then
    #     echo "$fish_init_cmd" >>"$fish_config"
    #     log_info "Added Starship init to $fish_config"
    # else
    #     log_info "Starship init already exists in $fish_config. Skipping."
    # fi

    # log_success "Starship setup completed."
}


install_vscode() {
    log_info "Installing VS Code..."
    sudo apt-get install -y wget gpg && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >packages.microsoft.gpg && \
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && \
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null && \
    rm -f packages.microsoft.gpg && \
    sudo apt install -y apt-transport-https && \
    sudo apt update -y && \
    sudo apt install -y code && \
    log_success "VS Code installed successfully." || log_error "Failed to install VS Code."
}

# Configure fcitx5 input method for Vietnamese typing
# configure_fcitx5() {
#     log_info "Configuring fcitx5 (Vietnamese input method)..."

#     # Install required packages
#     local fcitx5_packages=(fcitx5 fcitx5-frontend-gtk3 fcitx5-configtool fcitx5-bamboo)
#     for pkg in "${fcitx5_packages[@]}"; do install_software "$pkg"; done

#     mkdir -p "$FISH_CONFIG_DIR"

#     # Add environment variables to Fish and Bash
#     local envs_fish=(
#         'set -gx GTK_IM_MODULE fcitx5'
#         'set -gx QT_IM_MODULE fcitx5'
#         'set -gx XMODIFIERS "@im=fcitx5"'
#     )
#     local envs_bash=(
#         'export GTK_IM_MODULE=fcitx5'
#         'export QT_IM_MODULE=fcitx5'
#         'export XMODIFIERS="@im=fcitx5"'
#     )

#     for line in "${envs_fish[@]}"; do grep -qxF "$line" "$FISH_CONFIG_FILE" || echo "$line" >>"$FISH_CONFIG_FILE"; done
#     for line in "${envs_bash[@]}"; do grep -qxF "$line" "$HOME/.bashrc" || echo "$line" >>"$HOME/.bashrc"; done
#     grep -q "source ~/.bashrc" "$HOME/.bash_profile" || echo '[[ -f ~/.bashrc ]] && source ~/.bashrc' >>"$HOME/.bash_profile"

#     log_success "Fcitx5 configured."
# }

configure_fcitx5() {
    log_info "Configuring fcitx5 (Vietnamese input method)..."

    # Install required packages
    local fcitx5_packages=(fcitx5 fcitx5-frontend-gtk3 fcitx5-configtool fcitx5-bamboo)
    for pkg in "${fcitx5_packages[@]}"; do install_software "$pkg"; done

    # Ensure config directories exist if using separate files for shell config
    mkdir -p "$HOME/.config/fish" # Ensure Fish config directory exists if not already

    # Environment variables for different shells
    local envs_fish=(
        'set -gx GTK_IM_MODULE fcitx5'
        'set -gx QT_IM_MODULE fcitx5'
        'set -gx XMODIFIERS "@im=fcitx5"'
    )
    local envs_bash=(
        'export GTK_IM_MODULE=fcitx5'
        'export QT_IM_MODULE=fcitx5'
        'export XMODIFIERS="@im=fcitx5"'
    )
    local envs_zsh=(
        'export GTK_IM_MODULE=fcitx5'
        'export QT_IM_MODULE=fcitx5'
        'export XMODIFIERS="@im=fcitx5"'
    )

    # Determine the current shell to decide which config file to primarily target
    local current_shell=$(basename "$SHELL")

    # Add variables to Fish config
    if [ "$current_shell" = "fish" ]; then
        log_info "Adding Fcitx5 environment variables to Fish config."
        local FISH_CONFIG_FILE="$HOME/.config/fish/config.fish" # Main Fish config file
        for line in "${envs_fish[@]}"; do
            grep -qxF "$line" "$FISH_CONFIG_FILE" || echo "$line" >>"$FISH_CONFIG_FILE"
        done
        log_success "Fcitx5 variables added to Fish config."
    else
        # For Bash and Zsh, it's common to source a single file (like .bashrc or .zshrc)
        # from a login shell config (.profile or .zprofile) for consistency.

        # Add variables to Bash config (~/.bashrc)
        log_info "Adding Fcitx5 environment variables to Bash config (~/.bashrc)."
        local BASH_CONFIG_FILE="$HOME/.bashrc"
        for line in "${envs_bash[@]}"; do
            grep -qxF "$line" "$BASH_CONFIG_FILE" || echo "$line" >>"$BASH_CONFIG_FILE"
        done
        # Ensure .bashrc is sourced from .bash_profile for login shells
        grep -q '[[ -f ~/.bashrc ]] && source ~/.bashrc' "$HOME/.bash_profile" || echo '[[ -f ~/.bashrc ]] && source ~/.bashrc' >>"$HOME/.bash_profile"
        log_success "Fcitx5 variables added to Bash config."

        # Add variables to Zsh config (~/.zshrc)
        log_info "Adding Fcitx5 environment variables to Zsh config (~/.zshrc)."
        local ZSH_CONFIG_FILE="$HOME/.zshrc"
        for line in "${envs_zsh[@]}"; do
            grep -qxF "$line" "$ZSH_CONFIG_FILE" || echo "$line" >>"$ZSH_CONFIG_FILE"
        done
        # Ensure .zshrc is sourced from .zprofile for login shells (or .zshenv for all shells)
        # Choosing .zprofile for login shells, common for .zshrc.
        grep -q '[[ -f ~/.zshrc ]] && source ~/.zshrc' "$HOME/.zprofile" || echo '[[ -f ~/.zshrc ]] && source ~/.zshrc' >>"$HOME/.zprofile"
        log_success "Fcitx5 variables added to Zsh config."
    fi

    log_success "Fcitx5 configuration complete. Please restart your graphical session or reboot for full effect."
}

sync_keybindings(){
    xmodmap ~/linux-mint/.Xmodmap
    log_info "Loading custom keybindings configuration..."
    dconf load /org/cinnamon/desktop/keybindings/ <~/linux-mint/keybindings_config.dconf
    xmodmap ~/linux-mint/.Xmodmap

}

install_nodejs(){
    # Download and install nvm:
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

    # in lieu of restarting the shell
    \. "$HOME/.nvm/nvm.sh"

    # Download and install Node.js:
    nvm install --lts

    # Install Yarn
    npm install --global yarn
}


# --- Main ---

log_info "Updating APT packages list..."
sudo apt update || log_error "Failed to update APT packages list."

if ! command -v flatpak &>/dev/null; then
    log_info "Installing Flatpak..."
    sudo apt install -y flatpak && \
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && \
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
        flatpak install -y flathub "$flatpak_pkg" && \
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

read -p "Do you want to install NodeJS? (y/n): " install_nodejs_answer
[[ "$install_nodejs_answer" =~ ^[Yy]$ ]] && install_nodejs || log_info "Skipping NodeJS installation."

read -p "Do you want to install Fastfetch? (y/n): " install_fastfetch_answer
[[ "$install_fastfetch_answer" =~ ^[Yy]$ ]] && install_fastfetch || log_info "Skipping Fastfetch installation."

# read -p "Do you want to install VSCode? (y/n): " install_vscode_answer
# [[ "$install_vscode_answer" =~ ^[Yy]$ ]] && install_vscode || log_info "Skipping VSCode installation."

read -p "Do you want to install Lazydocker? (y/n): " install_lazydocker_answer
[[ "$install_lazydocker_answer" =~ ^[Yy]$ ]] && install_lazydocker || log_info "Skipping Lazydocker installation."

read -p "Do you want to install Warp? (y/n): " warp_answer
[[ "$warp_answer" =~ ^[Yy]$ ]] && configure_warp || log_info "Skipping Warp installation."

read -p "Do you want to install Nerd Font (JetBrainsMono)? (y/n): " font_answer
[[ "$font_answer" =~ ^[Yy]$ ]] && install_nerdfont || log_info "Skipping font installation."

read -p "Do you want to install Docker? (y/n): " docker_answer
[[ "$docker_answer" =~ ^[Yy]$ ]] && install_docker || log_info "Skipping Docker installation."

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
