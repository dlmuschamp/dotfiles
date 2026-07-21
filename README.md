# Dotfiles

This is a repo containing all customized dotfiles for my most used applications. They are mainly just quality of life tweaks to the default Omarchy set-up. This repo is essentially acting as a back-up so I can eventually use the same configuration on my desktop.

The configs include changes to:

```
- alacritty
- hypr
- mako
- nvim 
- sioyek 
- tmux 
- waybar
```

and some custom shell scripts I had for hardware events like plugging in headphones to activate spotify, swapping power profiles based on current battery percent, and enabling a "tablet" mode in:

```
- hardwareListner.sh 
```

Currently refactoring scripts in the new **automations/** to more broadly to use hardware interrupts instead of constantly polling daemons.

There is also a custom typst configuration in ```/bin``` that essentially allows me to run ```typst document_name``` and open an instance of nvim and sioyek to view the document as I edit it live. There is a general template for my typst documents located in ```typst/```.

**Future Plans**
I plan on creating a new branch just for the desktop but will keep the main branch for my laptop configuration.
