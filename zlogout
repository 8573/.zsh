() { emulate -L zsh

#{{{ Clear screen

() {
	local clear='/usr/bin/clear'

	if [[ $(echo $clear(Nu0f[go-w])) == $clear ]] {
		$clear
	}
}

#}}}

}
# vim: shiftwidth=8
