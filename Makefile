default: build

build: zshrc.zwc

zshrc.zwc: zshrc
	zsh -c 'zcompile zshrc'
