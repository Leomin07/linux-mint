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
FISH_SHELL="/usr/bin/fish"

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
  "gnome-shell-extension-manager"
  "fish"
  "btop"
  "neofetch"
)

SNAP_PACKAGES=(
  "dbeaver-ce"
  "postman"
  "code --classic"
  "dotnet-sdk --classic"
  "telegram-desktop"
  "brave"
  "go --classic"
)

# --- Helper Functions ---
log_info() { echo "[$(date '+%H:%M:%S')] >> $1"; }
log_success() { echo "✅ $1"; }
log_warning() { echo "⚠️ $1"; }

is_installed() {
  command -v "$1" &>/dev/null || dpkg -s "$1" &>/dev/null || snap list "$1" &>/dev/null
}

install_software() {
  local name="$1"
  local method="${2:-apt}"

  case "$method" in
  "apt")
    if ! is_installed "$name"; then
      sudo apt install -y "$name" && log_success "Đã cài đặt '$name'." || log_warning "Cài đặt '$name' thất bại."
    else
      log_info "'$name' đã được cài đặt, bỏ qua."
    fi
    ;;
  "snap")
    local pkg_name=$(echo "$name" | awk '{print $1}')
    if ! snap list "$pkg_name" &>/dev/null; then
      sudo snap install $name && log_success "Đã cài đặt '$name'." || log_warning "Cài đặt '$name' thất bại."
    else
      log_info "'$pkg_name' đã được cài đặt, bỏ qua."
    fi
    ;;
  *)
    log_warning "Phương thức cài đặt '$method' không được hỗ trợ."
    ;;
  esac
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

  # Add repo nếu chưa tồn tại
  if [ ! -f /etc/apt/sources.list.d/cloudflare-client.list ]; then
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
  fi

  sudo apt-get update
  sudo apt-get install -y cloudflare-warp

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
  go install github.com/jesseduffield/lazydocker@latest

  echo "alias lzd='sudo docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v ~/.config/jesseduffield/lazydocker lazyteam/lazydocker'" >>~/.config/fish/config.fish

}

install_ibus_bamboo() {
  if dpkg -s ibus-bamboo &>/dev/null; then
    log_info "ibus-bamboo đã được cài đặt, bỏ qua."
    return
  fi

  log_info "Cài đặt ibus-bamboo..."
  sudo add-apt-repository ppa:bamboo-engine/ibus-bamboo
  sudo apt-get update
  sudo apt-get install -y ibus ibus-bamboo --install-recommends
  ibus restart

  # Đặt ibus-bamboo làm bộ gõ mặc định
  env DCONF_PROFILE=ibus dconf write /desktop/ibus/general/preload-engines "['BambooUs', 'Bamboo']"
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'Bamboo')]"

  log_success "Đã cài đặt và cấu hình ibus-bamboo."
}

install_wine() {
  sudo dpkg --add-architecture i386

  sudo mkdir -pm755 /etc/apt/keyrings
  wget -O - https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key -

  sudo apt update

  sudo apt install --install-recommends winehq-stable

  wineboot
}

clone_wallpaper() {
  cd ~/Pictures # You can also choose a different location
  git clone --depth=1 https://github.com/mylinuxforwork/wallpaper.git
  cd wallpaper/
}

config_bat() {
  mkdir -p ~/.local/bin
  if [ ! -L ~/.local/bin/bat ] || [ "$(readlink ~/.local/bin/bat)" != "/usr/bin/batcat" ]; then
    ln -sf /usr/bin/batcat ~/.local/bin/bat
  fi
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

# --- Main ---

log_info "Cập nhật APT..."
sudo apt update

for pkg in "${APT_PACKAGES[@]}"; do
  install_software "$pkg" "apt"
done

for snap_pkg in "${SNAP_PACKAGES[@]}"; do
  install_software "$snap_pkg" "snap"
done

set_default_shell
install_fisher
install_fish_plugins
configure_git
install_lazydocker
config_bat
install_starship

read -p "🛡️ Ban co muon cai dat Warp khong? (y/n): " warp_answer
[[ "$warp_answer" =~ ^[Yy]$ ]] && configure_warp || log_info "Bo qua Warp."

read -p "🔤 Ban co muon cai Nerd Font khong? (y/n): " font_answer
[[ "$font_answer" =~ ^[Yy]$ ]] && install_nerdfont || log_info "Bo qua font."

read -p "🐳 Ban co muon cai Docker khong? (y/n): " docker_answer
[[ "$docker_answer" =~ ^[Yy]$ ]] && install_docker || log_info "Bo qua Docker."

read -p "🈶 Ban co muon cai ibus-bamboo khong? (y/n): " bamboo_answer
[[ "$bamboo_answer" =~ ^[Yy]$ ]] && install_ibus_bamboo || log_info "Bo qua ibus-bamboo."

read -p "📷 Bạn có muốn clone bộ hình nền không? (y/n): " clone_answer
if [[ "$clone_answer" =~ ^[Yy]$ ]]; then
  clone_wallpaper
else
  log_info "Bỏ qua bước clone wallpaper."
fi

# dconf load /org/gnome/shell/extensions/ <~/ubuntu/dump_extensions.txt

clean_apt

log_success "🎉 Thiết lập môi trường hoàn tất!"
