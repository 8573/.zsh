emulate -R zsh; set -u

setopt ExtendedGlob

local -aU path fpath manpath zshfuncs

path=(
	"$(<~/.userOverrideDir)/bin"
	# Nix packages.
	~/.nix-profile/bin
	# MacPorts packages.
	/opt/local/bin
	# FHS `bin` paths.
	/usr/local/bin
	/usr/bin
	/bin
	# Pip packages.
	/opt/local/Library/Frameworks/Python.framework/Versions/2.7/bin
	# Gem packages.
	~/.gem/ruby/1.8/bin
	# Whatever other paths.
	$path
)

# Filter out world-writable directories.
path=(${^path}(N/f[o-w]))

fpath=(
	/opt/local/share/zsh/*/functions(N)
	$fpath
)

fpath=(${^fpath}(N/u0f[go-w]))

#manpath=(… $manpath)
#
# Apparently, Mac OS X doesn’t set the environment variable `$MANPATH` by
# default, but rather only uses `MANPATH` statements in `man.conf`, which are
# overridden by `$MANPATH` — so, if I want to add a path, it seems I must
# either edit `man.conf` or copy the paths thence and set `$MANPATH` myself.
# I’ll take the latter route.
#
# Default `$MANPATH`.
manpath=(/usr/share/man /usr/local/share/man /usr/X11/man)
# `$MANPATH` additions.
manpath=(/opt/local/share/man $manpath)

manpath=(${^manpath}(N/u0f[o-w]))

zshfuncs=(${^fpath}/[^_.](*~*.zwc)(N.u0f[go-w]e['REPLY=${REPLY:t}']))

if [[ $- == *i* ]] {
	emulate zsh -c "autoload -Uz ${(j[ ])${(@q)zshfuncs}}"
}

emulate zsh
