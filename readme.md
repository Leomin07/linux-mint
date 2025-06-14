### Dump setting extensions

- Dump

```
 dconf dump /org/cinnamon/desktop/keybindings/  > ~/linux-mint/keybindings_config.dconf
```

- Load file

```
 dconf load /org/cinnamon/desktop/keybindings/  < ~/linux-mint/keybindings_config.dconf
```

### Virtual Machine Manager

```
sudo apt install ssh-askpass virt-manager -y
```

### Map key

```
xmodmap ~/linux-mint/.Xmodmap
```
```
cp ~/linux-mint/map-key.desktop ~/.config/autostart

```