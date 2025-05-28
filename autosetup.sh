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
    "nodejs"
    "yarn"
    "npm"
    "dotnet-sdk-8.0"
    "ffmpeg"
    "bat"
    "fzf"
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
    "notion"
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
log_info() { echo "[$(date '+%H:%M:%S')] >> $1"; }
log_success() { echo "✅ $1"; }
log_warning() { echo "⚠️ $1"; }

is_installed() {
    command -v "$1" &>/dev/null || dpkg -s "$1" &>/dev/null
}

# Install Fastfetch
install_fastfetch(){
    sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
    sudo apt install fastfetch -y
}

install_software() {
    local name="$1"
    if ! is_installed "$name"; then
        sudo apt install -y "$name" && log_success "Đã cài đặt '$name'." || log_warning "Cài đặt '$name' thất bại."
    else
        log_info "'$name' đã được cài đặt, bỏ qua."
    fi
}

configure_git() {
    git config --global user.name "$USER_NAME"
    git config --global user.email "$USER_EMAIL"
    if [ ! -f "$SSH_KEY_FILE" ]; then
        log_info "Tạo SSH key mới..."
        ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$SSH_KEY_FILE" -N ""
        log_success "Đã tạo SSH key."
    else
        log_info "SSH key đã tồn tại, bỏ qua."
    fi
}

configure_warp() {
    # Add Cloudflare GPG key nếu chưa tồn tại
    if [ ! -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]; then
        log_info "Đang thêm GPG key của Cloudflare Warp..."
        curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    fi


    # Add this repo to your apt repositories
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ bookworm main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list


    # Install
    sudo apt-get update && sudo apt-get install cloudflare-warp

    # Xóa đăng ký cũ nếu có
    log_info "Đang xóa đăng ký Warp cũ (nếu có)..."
    warp-cli registration delete || true
    
    # Đăng ký và kết nối Warp
    log_info "Đang đăng ký Warp mới..."
    warp-cli registration new
    warp-cli connect
}

clean_apt() {
    log_info "Dọn dẹp APT..."
    sudo apt autoremove -y && sudo apt clean
    log_success "Đã dọn dẹp xong."
}

install_zsh() {
    if ! command -v zsh &>/dev/null; then
        log_info "Cài đặt Zsh..."
        sudo apt install -y zsh && log_success "Đã cài Zsh." || log_warning "Cài Zsh thất bại."
    else
        log_info "Zsh đã có, bỏ qua."
    fi

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Cài đặt Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && log_success "Đã cài Oh My Zsh."
    else
        log_info "Oh My Zsh đã có, bỏ qua."
    fi

    local real_user="${SUDO_USER:-$USER}"
    if [ "$SHELL" != "/usr/bin/zsh" ]; then
        log_info "Đổi shell mặc định sang Zsh..."
        sudo chsh -s "$(which zsh)" "$real_user"
        log_success "Đã đổi shell mặc định sang Zsh (đăng xuất để áp dụng)."
    else
        log_info "Shell mặc định đã là Zsh."
    fi
}

install_zsh_plugins() {
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

    declare -A plugins=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
        ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
    )

    for name in "${!plugins[@]}"; do
        local dir="$plugins_dir/$name"
        if [ ! -d "$dir" ]; then
            log_info "Cài plugin $name..."
            git clone "${plugins[$name]}" "$dir" && log_success "Đã cài $name." || log_warning "Cài $name thất bại."
        else
            log_info "$name đã được cài, bỏ qua."
        fi
    done

    log_info "⚠️ Nhớ thêm 'zsh-autosuggestions zsh-syntax-highlighting zsh-completions' vào plugins trong ~/.zshrc"
}

install_nerdfont() {
    mkdir -p ~/.local/share/fonts
    if fc-list | grep -i "JetBrainsMono" &>/dev/null; then
        log_info "Font JetBrainsMono đã được cài đặt, bỏ qua."
    else
        log_info "Đang tải và cài đặt font JetBrainsMono..."
        wget -O ~/.local/share/fonts/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip &&
            cd ~/.local/share/fonts &&
            unzip -o JetBrainsMono.zip &&
            rm JetBrainsMono.zip &&
            fc-cache -fv

        log_success "Đã cài đặt font JetBrainsMono thành công."
    fi
}

install_docker() {
    if command -v docker &>/dev/null; then
        echo "✅ Docker is already installed. Skipping installation."
        return
    fi

    echo "🚀 Installing Docker..."

    # Cập nhật và cài đặt các gói cần thiết
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl

    # Tạo thư mục chứa keyrings nếu chưa có
    sudo install -m 0755 -d /etc/apt/keyrings

    # Tải và thiết lập quyền cho Docker GPG key
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Thêm Docker repository vào sources list
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    # Cập nhật và cài đặt Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "✅ Docker installation completed."
}

set_default_shell() {
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    if [ "$current_shell" != "$FISH_SHELL" ]; then
        log_info "Changing default shell to fish for user $USER..."
        sudo chsh -s "$FISH_SHELL" "$USER"
    else
        log_info "Default shell is already fish."
    fi
}

install_fisher() {
    if ! fish -c "type -q fisher"; then
        log_info "Installing fisher..."
        fish -c 'curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher'
    else
        log_info "Fisher is already installed, skipping."
    fi
}

install_fish_plugins() {
    for plugin in "${FISH_PLUGINS[@]}"; do
        if ! fish -c "fisher list | grep -q '$plugin'"; then
            log_info "Installing Fish plugin: $plugin"
            fish -c "fisher install $plugin"
        else
            log_info "Fish plugin '$plugin' is already installed."
        fi
    done
}

install_lazydocker() {
    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

    # echo "alias lzd='sudo docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v ~/.config/jesseduffield/lazydocker lazyteam/lazydocker'" >>~/.config/fish/config.fish
    # Tạo thư mục config nếu chưa có
    mkdir -p "$FISH_CONFIG_DIR"

    # Alias cho LazyDocker dùng container
    local alias_line="alias lzd='sudo docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v ~/.config/jesseduffield/lazydocker lazyteam/lazydocker'"

    # Tránh thêm trùng lặp
    grep -qxF "$alias_line" "$FISH_CONFIG_FILE" || echo "$alias_line" >>"$FISH_CONFIG_FILE"

    log_success "Alias for LazyDocker added to Fish config."

}

clone_wallpaper() {
    cd ~/Pictures # You can also choose a different location
    git clone --depth=1 https://github.com/Leomin07/wallpaper.git ~/Pictures/wallpaper
    cd wallpaper/
}


install_starship() {
    echo "[INFO] Installing Starship prompt..."

    # Install Starship if not already installed
    if ! command -v starship &>/dev/null; then
        echo "[INFO] Starship not found. Downloading and installing..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    else
        echo "[INFO] Starship is already installed. Skipping installation."
    fi

    # Function to append init command if not already present
    add_starship_init() {
        local shell_rc="$1"
        local shell_name="$2"
        local init_cmd="eval \"\$(starship init $shell_name)\""

        if ! grep -Fxq "$init_cmd" "$shell_rc"; then
            echo "$init_cmd" >>"$shell_rc"
            echo "[INFO] Added Starship init to $shell_rc"
        else
            echo "[INFO] Starship init already exists in $shell_rc. Skipping."
        fi
    }

    # Configure for bash
    if [ -f ~/.bashrc ]; then
        add_starship_init ~/.bashrc bash
    fi

    # Configure for fish
    fish_config="$HOME/.config/fish/config.fish"
    fish_init_cmd='starship init fish | source'
    mkdir -p "$(dirname "$fish_config")"
    if ! grep -Fxq "$fish_init_cmd" "$fish_config"; then
        echo "$fish_init_cmd" >>"$fish_config"
        echo "[INFO] Added Starship init to $fish_config"
    else
        echo "[INFO] Starship init already exists in $fish_config. Skipping."
    fi

    echo "[INFO] Starship setup completed."
}

install_vscode() {
    sudo apt-get install wget gpg -y
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    rm -f packages.microsoft.gpg

    sudo apt install apt-transport-https -y
    sudo apt update -y
    sudo apt install code -y

}

# Configure fcitx5 input method for Vietnamese typing
configure_fcitx5() {
    log_info "Configuring fcitx5..."

    # Install required packages
    local fcitx5_packages=(fcitx5 fcitx5-frontend-gtk3 fcitx5-configtool fcitx5-bamboo)
    for pkg in "${fcitx5_packages[@]}"; do install_software "$pkg"; done

    mkdir -p "$FISH_CONFIG_DIR"

    # Add environment variables to Fish and Bash
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

    for line in "${envs_fish[@]}"; do grep -qxF "$line" "$FISH_CONFIG_FILE" || echo "$line" >>"$FISH_CONFIG_FILE"; done
    for line in "${envs_bash[@]}"; do grep -qxF "$line" "$HOME/.bashrc" || echo "$line" >>"$HOME/.bashrc"; done
    grep -q "source ~/.bashrc" "$HOME/.bash_profile" || echo '[[ -f ~/.bashrc ]] && source ~/.bashrc' >>"$HOME/.bash_profile"

    log_success "Fcitx5 configured."
}

# --- Main ---

log_info "Cập nhật APT..."
sudo apt update

if ! command -v flatpak &>/dev/null; then
    log_info "Cài đặt Flatpak..."
    sudo apt install -y flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

for pkg in "${APT_PACKAGES[@]}"; do
    install_software "$pkg" "apt"
done

for flatpak_pkg in "${FLATPAK_PACKAGES[@]}"; do
    if ! flatpak list --app | grep -q "$flatpak_pkg"; then
        log_info "Cài đặt Flatpak app: $flatpak_pkg"
        flatpak install -y flathub "$flatpak_pkg"
    else
        log_info "$flatpak_pkg đã được cài đặt qua Flatpak, bỏ qua."
    fi
done

set_default_shell
install_fisher
install_fish_plugins
configure_git
install_lazydocker
install_starship
install_fastfetch

read -p "Ban co muon cai dat VSCode khong? (y/n): " install_vscode
[[ "$install_vscode" =~ ^[Yy]$ ]] && install_vscode || log_info "Bo qua VSCode."

read -p "Ban co muon cai dat lazydocker khong? (y/n): " install_lazydocker
[[ "$install_lazydocker" =~ ^[Yy]$ ]] && install_lazydocker || log_info "Bo qua lazydocker."

read -p "Ban co muon cai dat Warp khong? (y/n): " warp_answer
[[ "$warp_answer" =~ ^[Yy]$ ]] && configure_warp || log_info "Bo qua Warp."

read -p "Ban co muon cai Nerd Font khong? (y/n): " font_answer
[[ "$font_answer" =~ ^[Yy]$ ]] && install_nerdfont || log_info "Bo qua font."

read -p "Ban co muon cai Docker khong? (y/n): " docker_answer
[[ "$docker_answer" =~ ^[Yy]$ ]] && install_docker || log_info "Bo qua Docker."

read -p "Ban co muon cai fcitx5 khong? (y/n): " configure_fcitx5
[[ "$configure_fcitx5" =~ ^[Yy]$ ]] && configure_fcitx5 || log_info "Bo qua configure_fcitx5."

read -p "Bạn có muốn clone bộ hình nền không? (y/n): " clone_answer
if [[ "$clone_answer" =~ ^[Yy]$ ]]; then
    clone_wallpaper
else
    log_info "Bỏ qua bước clone wallpaper."
fi

dconf load /org/cinnamon/desktop/keybindings/ <~/linux-mint/keybindings_config.dconf

clean_apt

log_success "🎉 Thiết lập môi trường hoàn tất!"
