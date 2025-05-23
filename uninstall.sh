#!/bin/bash
set -e

log_info() { echo "[$(date '+%H:%M:%S')] >> $1"; }
log_success() { echo "✅ $1"; }
log_warning() { echo "⚠️ $1"; }

APT_PACKAGES=(
    "python3"
    "python3-pip"
    "python3-tk"
    "python3-venv"
    "nodejs"
    "yarn"
    "npm"
    "ffmpeg"
    "vim"
    "neovim"
    "kitty"
    "alacritty"
    "mpv"
    "curl"
    "stow"
    "tmux"
    "gnome-shell-extension-manager"
    "fish"
    "zsh"
)

SNAP_PACKAGES=(
    "dbeaver-ce"
    "postman"
    "code"
    "dotnet-sdk"
    "telegram-desktop"
    "brave"
    "go"
)

remove_apt_packages() {
    log_info "Gỡ cài đặt các gói APT..."
    sudo apt purge -y "${APT_PACKAGES[@]}" || log_warning "Gỡ APT lỗi, tiếp tục..."
    sudo apt autoremove -y
    sudo apt clean
    log_success "Đã gỡ các gói APT."
}

remove_snap_packages() {
    log_info "Gỡ cài đặt các gói Snap..."
    for snap_pkg in "${SNAP_PACKAGES[@]}"; do
        sudo snap remove "$(echo $snap_pkg | awk '{print $1}')" || log_warning "Không thể gỡ $snap_pkg"
    done
    log_success "Đã gỡ các gói Snap."
}

remove_docker() {
    log_info "Gỡ Docker..."
    sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo rm -rf /var/lib/docker /etc/docker /etc/apt/keyrings/docker.asc /etc/apt/sources.list.d/docker.list
    log_success "Đã gỡ Docker."
}

remove_warp() {
    log_info "Gỡ Warp..."
    sudo apt purge -y cloudflare-warp
    sudo rm -f /etc/apt/sources.list.d/cloudflare-client.list
    sudo rm -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    log_success "Đã gỡ Warp."
}

remove_zsh_plugins() {
    rm -rf ~/.oh-my-zsh
    log_info "Đã xóa Oh My Zsh."
}

remove_fish_plugins() {
    fish -c "fisher remove all" || true
    rm -rf ~/.config/fish/functions/fisher.fish ~/.config/fish/functions/*.fish ~/.config/fish/completions ~/.config/fish/conf.d
    log_info "Đã gỡ plugin Fish."
}

remove_nerdfont() {
    rm -f ~/.local/share/fonts/JetBrainsMono*
    fc-cache -fv
    log_info "Đã gỡ Nerd Font."
}

remove_ibus_bamboo() {
    sudo apt purge -y ibus-bamboo ibus
    sudo add-apt-repository --remove ppa:bamboo-engine/ibus-bamboo
    log_info "Đã gỡ ibus-bamboo."
}

remove_wallpaper_repo() {
    rm -rf ~/Pictures/wallpaper
    log_info "Đã xóa thư mục hình nền wallpaper."
}

remove_lazydocker() {
    rm -f ~/go/bin/lazydocker
    sed -i '/alias lzd=/d' ~/.config/fish/config.fish
    log_info "Đã gỡ lazydocker và alias."
}

# --- Run All Uninstall ---
remove_apt_packages
remove_snap_packages
remove_docker
remove_warp
remove_zsh_plugins
remove_fish_plugins
remove_nerdfont
remove_ibus_bamboo
remove_wallpaper_repo
remove_lazydocker

log_success "🧹 Gỡ cài đặt hoàn tất!"
