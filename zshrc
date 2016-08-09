emulate -R zsh -u

#{{{ Non-interactive shells should skip this script

# Apparently required for `scp`.
if [[ $- != *i* ]] {
   return
}

#}}}
#{{{ Timing, start

local -F SECONDS

readonly -F ZSHRC_start_time=$SECONDS

# If this is non-null, it overrides all the other report thresholds below.
readonly ZSHRC_runtime_report_threshold_override=

# Minimum duration, in seconds, for which a section of this `zshrc` script
# must run for that section’s run-time to be reported to the user.
readonly -F ZSHRC_rc_section_runtime_report_threshold=\
${ZSHRC_runtime_report_threshold_override:-0.125}

# Minimum duration, in seconds, for which this `zshrc` script must run for its
# (mostly) total run-time to be reported to the user.
readonly -F ZSHRC_rc_total_runtime_report_threshold=\
${ZSHRC_runtime_report_threshold_override:-1}

# Minimum quantity of seconds by which the (mostly) total run-time of this
# `zshrc` script must exceed the sum of the recorded run-times of its sections
# for that discrepancy to be reported to the user.
readonly -F ZSHRC_rc_total_runtime_variance_report_threshold=\
${ZSHRC_runtime_report_threshold_override:-0.25}

# Like `ZSHRC_rc_total_runtime_report_threshold`, but for the whole
# initialization process, not just this `zshrc` script.
readonly -F ZSHRC_initztn_total_runtime_report_threshold=\
${ZSHRC_runtime_report_threshold_override:-0}

# Like `ZSHRC_rc_total_runtime_variance_report_threshold`, but for the whole
# initialization process, not just this `zshrc` script (though it still
# compares to the sum of this `zshrc` script’s sections).
readonly -F ZSHRC_initztn_total_runtime_variance_report_threshold=\
${ZSHRC_runtime_report_threshold_override:-0.25}

local -F ZSHRC_mark_time_timer=$ZSHRC_start_time
local -F ZSHRC_mark_time_total=0
local -F ZSHRC_mark_time_total_reported=0
function mark-time {
   (( $# == 1 || $# == 2 )) || {
      echo-help 'usage: mark-time <span name> [<duration in seconds>]'
      return 2
   }

   readonly -F t=${2:-$(( $SECONDS - $ZSHRC_mark_time_timer ))}

   (( ZSHRC_mark_time_total += $t ))

   if (( $t >= $ZSHRC_rc_section_runtime_report_threshold )) {
      mark-time-chirp $1 $t
      (( ZSHRC_mark_time_total_reported += $t ))
   }

   if (( $# != 2 )) {
      ZSHRC_mark_time_timer=$SECONDS
   }
}

function mark-time-chirp {
   if [[ -z ${ZSHRC_QUIET-} ]] {
      printf '%s---- %- 34s %f s%s\n' \
         ${(%):-'%F{blue}'} $@ ${(%):-'%f'}
   }
}

mark-time 'pre-zshrc initialization' $ZSHRC_start_time

mark-time 'timing setup'

#}}}
#{{{ Shell options

setopt \
   AppendHistory\
   AutoCD\
   AutoList\
   AutoMenu\
   AutoNameDirs\
   AutoParamKeys\
   AutoPushD\
   BadPattern\
   BareGlobQual\
   CBases\
   CDableVars\
   CheckJobs\
   NoClobber\
   CombiningChars\
   CorrectAll\
   ExtendedGlob\
   ExtendedHistory\
   NoFlowControl\
   NoHUP\
   HashListAll\
   HistExpireDupsFirst\
   HistFcntlLock\
   HistFindNoDups\
   HistIgnoreDups\
   HistIgnoreSpace\
   HistLexWords\
   HistNoStore\
   HistReduceBlanks\
   HistVerify\
   IgnoreEOF\
   InteractiveComments\
   KshGlob\
   ListAmbiguous\
   NoListBeep\
   ListTypes\
   LongListJobs\
   NoMatch\
   MultIOs\
   MultiByte\
   NoNotify\
   PathDirs\
   PipeFail\
   NoPosixBuiltins\
   PosixIdentifiers\
   NoPromptSubst\
   PushDIgnoreDups\
   REMatchPCRE\
   NoRmStarSilent\
   RmStarWait\
   NoShortLoops\
   Unset\
   WarnCreateGlobal\

umask 077

mark-time 'shell options'

#}}}
#{{{ Initial shell parameters

ZSHRC_PATH="${${(%):-%N}:A}"

export ZSHRC_QUIET=${ZSHRC_QUIET-}

if [[ -z $ZSHRC_UNICODE ]] {
   case $TERM {
      (xterm-*|screen-256*)
         ZSHRC_UNICODE='✓'
   }
}

local -a ZSHRC_run_at_shell_entry

# Functions to run before prompt is printed.
local -a precmd_functions

precmd_functions=(
   reset-window-title
)

# Functions to run before a command is executed.
local -a preexec_functions

preexec_functions=(
)

mark-time 'initial shell parameters'

#}}}
#{{{ Initial functions

function zshrc-chirp {
   if [[ $# == 0 || ( $# == 1 && $1 == (-h|--help) ) ]] {
      echo 'usage: zshrc-chirp <word>...
If `$ZSHRC_QUIET` is unset or null, runs the <word>s as a command.' >&2
      return 2
   }
   if [[ -z $ZSHRC_QUIET ]] {
      $@
   }
}

function zshrc-chirp-toned {
   if [[ -z $ZSHRC_QUIET ]] {
      echo -n ${(%):-'%F{blue}'}
      $@
      echo -n ${(%):-'%f'}
   }
}

function run-at-shell-entry {
   (( $# == 1 )) || {
      echo-help 'usage: run-at-shell-entry <command>'
      return 2
   }

   ZSHRC_run_at_shell_entry+=$1
}

function dbg-echo {
   echo $@ >&2
}

function echo-err {
   echo $@ >&2
}

function echo-help {
   echo $@ >&2
}

function echo-raw {
   echo -E - $@
}

function check {
   emulate -L zsh; set -u

   (( $# >= 1 && $# <= 2 )) || {
      echo-help 'Usage: check [<message>] <predicate>

If <predicate>, evaluated as the body of an anonymous function prefixed with
`emulate -L zsh; setopt ERR_EXIT NO_UNSET PIPE_FAIL;`, returns false (i.e.
exits with a non-zero exit status code), `check` outputs an error message to
the standard error stream and returns the same exit status code as
<predicate>.

<predicate>’s standard input, output, and error streams are bound to the null
device (`/dev/null`).'
      return 2
   }

   local msg='' pred=''
   if (( $# == 2 )) {
      msg=$1
      pred=$2
   } else {
      pred=$1
   }

   eval "() {
      emulate -L zsh; setopt ERR_EXIT NO_UNSET PIPE_FAIL; $pred
   } </dev/null &>/dev/null" || {
      readonly r=$?
      echo-err "ASSERTION FAILED: ${msg:-${(q-)pred}}"
      return $r
   }
}

function assert {
   (( $# >= 1 && $# <= 2 )) || {
      echo-help 'Usage: assert [<message>] <predicate>

If <predicate>, evaluated as the body of an anonymous function prefixed with
`emulate -L zsh; setopt ERR_EXIT NO_UNSET PIPE_FAIL;`, returns false (i.e.
exits with a non-zero exit status code), `assert` outputs an error message to
the standard error stream and exits the script with the same exit status code
as <predicate>.

<predicate>’s standard input, output, and error streams are bound to the null
device (`/dev/null`).'
      return 2
   }

   check $@ || exit $?
}

function any {
   emulate -L zsh; set -u

   (( $# >= 1 )) || {
      echo-help 'Usage: any <predicate> [<item>...]

For each <item>, <predicate> is evaluated as a zsh command, with the <item> as
argument.

If <predicate> returns true for any <item>, `any` returns true. Otherwise, or
if there are no <item>s, `any` returns false.

Examples:
  - Check whether any files in the current working directory have names ending
    with `.txt`:
      $ '"any '() { [[ \$1 == *.txt ]] }' *"'
  - Check whether any of the words `Linux`, `illumos`, or `BSD` appear in the
    output of `uname -a`:
      $ '"any '() { [[ \$(uname -a) =~ \$1 ]] }' Linux illumos BSD"'

See also: `all`'
      return 2
   }

   for item (${@:2}) {
      if {eval "$1 ${(q)item}"} {
         return 0
      }
   }
   return 1
}
check 'any "() { [[ \$(echo foo illumos bar) =~ \$1 ]] }" Linux illumos BSD'

function all {
   emulate -L zsh; set -u

   (( $# >= 1 )) || {
      echo-help 'Usage: all <predicate> [<item>...]

For each <item>, <predicate> is evaluated as a zsh command, with the <item> as
argument.

If <predicate> returns false for any <item>, `all` returns false. Otherwise,
or if there are no <item>s, `all` returns true.

Examples:
  - Check whether all files in the current working directory have names ending
    with `.txt`.
      $ '"all '() { [[ \$1 == *.txt ]] }' *"'
  - Check whether all of the words `Linux`, `illumos`, and `BSD` appear in the
    file `foo.mkd`:
      $ '"all '() { [[ \$(<foo.mkd) =~ \$1 ]] }' Linux illumos BSD"'

See also: `any`'
      return 2
   }

   for item (${@:2}) {
      if {! eval "$1 ${(q)item}"} {
         return 1
      }
   }
   return 0
}
check 'all "() {
   [[ \$(echo Linux foo illumos bar BSD) =~ \$1 ]]
}" Linux illumos BSD'

function first-where {
   (( $# >= 1 )) || {
      echo-help 'Usage: first-where <predicate> [<item>...]'
      return 2
   }

   any '() { { '"$1"' $1 } && echo-raw $1 }' ${@:2}
}
check '[[ $(first-where "test Idris =" Rust Idris Mercury) == Idris ]]'

function take-while {
   (( $# >= 1 )) || {
      echo-help 'Usage: take-while <predicate> [<item>...]'
      return 2
   }

   all '() { { '"$1"' $1 } && echo-raw $1 }' ${@:2}
   true
}
check "[[ \$(take-while 'test Eff !=' ML OCaml Eff) == \$'ML\nOCaml' ]]"

function filter {
   (( $# >= 1 )) || {
      echo-help 'Usage: filter <predicate> [<item>...]'
      return 2
   }

   for item (${@:2}) {
      if {eval "$1 ${(q)item}"} {
         echo-raw $item
      }
   }
}
check "[[ \$(filter 'test 5 -gt' 1 7 2 6) == \$'1\n2' ]]"

function file-qualifies {
   emulate -L zsh; set -u

   (( $# == 2 )) || {
      echo-help 'Usage: file-qualifies <glob qualifiers> <file>'
      return 2
   }

   readonly quals=$1 file=${2:A}

   [[ -e $file ]] || {
      echo-err 'error: File '"${(q-)2}"' not found.'
      return 3
   }

   [[ $(echo $file(N$quals)) == $file ]]
}

function files-qualify {
   (( $# >= 2 )) || {
      echo-help 'Usage: files-qualify <glob qualifiers> <file>...'
      return 2
   }

   readonly quals=$1

   all 'file-qualifies $quals' ${@:2}
}

function qualifying-files {
   (( $# >= 1 )) || {
      echo-help 'Usage: qualifying-files <glob qualifiers> [<file>...]'
      return 2
   }

   readonly quals=$1

   filter 'file-qualifies $quals' ${@:2}
}

function cmd-exists {
   (( $# == 1 )) || {
      echo-help 'Usage: cmd-exists <name>'
      return 2
   }

   which -- $1 >'/dev/null'
}

function executable-exists {
   (( $# == 1 )) || {
      echo-help 'Usage: executable-exists <name>'
      return 2
   }

   which -p -- $1 >'/dev/null'
}

function which-if-any {
   which $@ >'/dev/null' &&
      which $@
}

function is-zsh-fn {
   (( $# == 1 )) || {
      echo-help 'Usage: is-zsh-fn <name>'
      return 2
   }

   [[ $(type -w $1) == "$1: function" ]]
}

function first-cmd-of {
   first-where cmd-exists $@
}

function array-index-of {
   (( $# >= 1 )) || {
      echo 'usage: array-index-of <string> [<array element>...]'
      return 2
   }

   readonly target=$1

   integer i=0

   local element
   for element (${@:2}) {
      (( ++i ))

      if [[ $element == $target ]] {
         echo $i
         return 0
      }
   }
   return 1
}
check '[[ $(array-index-of Idris Rust Idris Mercury) == 2 ]]'

function array-contains {
   (( $# >= 1 )) || {
      echo-help 'Usage: array-contains <quarry> [<array element>...]'
      return 2
   }

   any "() { [[ ${(q)1} == \$1 ]] }" ${@:2}
}
check 'array-contains Idris Rust Idris Mercury'
check '! array-contains Idris Perl PHP Python'

function path-lookup {
   emulate -L zsh; set -u

   (( $# >= 2 )) || {
      echo-help 'usage: path-lookup <test type> <file> <dir to search>...
       path-lookup ([) <test type> <file>... (]) <dir to search>...'
      return 2
   }

   if [[ $1 != '[' ]] {
      readonly test=$1 file=$2

      any '() {
         [[ '"${(q)test}"' "$1/$file" ]] && echo -E "$1/$file"
      }' ${@:2}
   } else {
      readonly test=$2
      local -a files dirs
      integer files_break=$(array-index-of ']' $@)

      files=(${@: 3 : files_break - 3 })
      dirs=(${@: files_break + 1 })

      any '() {
         any "path-lookup \$test $1" $dirs
      }' $files
   }
}

function PATH-lookup {
   (( $# == 3 )) || {
      echo-help 'usage: PATH-lookup <test type> <file> <search path>'
      return 2
   }

   path-lookup $1 $2 ${(s.:.)3}
}

function file-is-an-executable {
   (( $# == 1 )) || {
      echo 'usage: file-is-an-executable <file>' >&2
      return 2
   }

   [[ -x $1 && ! -d $1 ]]
}

function have-GNU-system {
   [[ $(uname -a) == (#i)*GNU* ]]
}

function have-Darwin-system {
   [[ $(uname -a) == (#i)*Darwin* ]]
}

function have-MacPorts {
   [[ -d '/opt/local/etc/macports' ]] &&
   [[ -x '/opt/local/bin/port'     ]]
}

function get-owner-id {
   emulate -L zsh
   setopt ExtendedGlob

   # Resolve <file> to an absolute path, in case it begins with `-`.
   readonly type=$1 f=${2:a}

   [[ $# == 2 && $type == [ug] ]] || {
      echo 'usage: get-owner-id (u|g) <file>' >&2
      return 2
   }

   local stat

   for stat ({z,}stat) {
      if [[ $(type -w $stat) == "$stat: builtin" ]] {
         builtin $stat "+${type}id" $f
         return $?
      }
   }

   local stat_arg
   if {have-GNU-coreutil stat} {
      stat_arg='-c'
   } else {
      stat_arg='-f'
   }

   run-secure-base stat $stat_arg "%${type}" $f
}

function get-owner-uid {
   (( $# == 1 )) || {
      echo 'usage: get-owner-uid <file>' >&2
      return 2
   }

   get-owner-id u $1
}

function get-owner-gid {
   (( $# == 1 )) || {
      echo 'usage: get-owner-gid <file>' >&2
      return 2
   }

   get-owner-id g $1
}

function file-is-owned-by-me-or-root {
   (( $# == 1 )) || {
      echo 'usage: file-is-owned-by-me-or-root <file>' >&2
      return 2
   }

   [[ -O $1 ]] || [[ $(get-owner-uid $1) == 0 ]]
}

function file-is-not-writable-to-others {
   (( $# == 1 )) || {
      echo 'usage: file-is-not-writable-to-others <file>' >&2
      return 2
   }

   file-qualifies 'f:go-w:' $1
}

function file-is-not-accessible-to-others {
   (( $# == 1 )) || {
      echo 'usage: file-is-not-accessible-to-others <file>' >&2
      return 2
   }

   file-qualifies 'f:go-rwx:' $1
}

function file-is-secure {
   (( $# == 1 )) || {
      echo 'Usage: file-is-secure <file>

If <file> is owned by the invoking user or by the root user (UID 0), and is
not writable to users other than its owner, returns true; otherwise, returns
false.

Note: Returns true even if <file> is not writable to its owner.' >&2
      return 2
   }

   file-is-owned-by-me-or-root $1 &&
      file-is-not-writable-to-others $1
}

function file-is-private {
   (( $# == 1 )) || {
      echo 'Usage: file-is-private <file>

If <file> is owned by the invoking user or by the root user (UID 0), and is
not readable, writable, or executable to users other than its owner, returns
true; otherwise, returns false.

Note: Returns true even if <file> is not readable, writable, or executable to
its owner.' >&2
      return 2
   }

   file-is-owned-by-me-or-root $1 &&
      file-is-not-accessible-to-others $1
}

function select-secure-executable {
   emulate -L zsh; set -u

   { (( $# >= 3 )) && [[ $1 == -[-weq] ]] } || {
      echo-help 'Usage: select-secure-executable (-w | -e | -q | --) <name> <executable>...

Prints, to the standard output stream, the first <executable> that:
  - exists, and
  - is executable by the current user, and
  - is secure (owned by the current user or by the root (UID 0) user, and not
    writable to users other than its owner).

If `-w` is given, then a warning message will be emitted, to the standard
error stream, for each <executable> that exists and is executable by the
current user but is not secure; and this function’s exit status code will be
zero if a <executable> is printed, and non-zero otherwise.

If `-e` is given, then the presence of an <executable> that exists and is
executable by the current user but is not secure results in this function
emitting an error message, to the standard error stream, and exiting with a
non-zero exit status code.

`-q` has the same effect as `-w`, except that this function will not emit any
warnings about insecure executables.

`--` has the same effect as `-w`, at least for now.

<name> is the name of what all the given executables are supposed to
implement, to be used in warning messages and error messages.

If `+` appears as an <executable>, it will be expanded to all the executables
found by `which -ap -- <name>`.'
      return 2
   }

   readonly fail_type=$1 name=$2
   local -aU exes secure_exes insecure_exes

   if [[ $fail_type == '--' ]] {
      fail_type='-w'
   }

   local exe

   for exe (${@:3}) {
      if [[ $exe == '+' ]] {
         if {executable-exists $name} {
            exes+=(${(f)"$(which-if-any -ap -- $name)"})
         }
      } else {
         exes+=$exe
      }
   }

   for exe ($exes) {
      if [[ -x $exe ]] {
         if { file-is-secure $exe } {
            secure_exes+=$exe
         } else {
            insecure_exes+=$exe
         }
      }
   }

   if [[ $fail_type != '-q' ]] {
      readonly errfmt=${(%):-'%B%F{red}'}
      readonly infofmt=${(%):-'%B%F{cyan}'}
      readonly unfmt=${(%):-'%f%b'}

      for exe ($insecure_exes) {
         echo-err "${errfmt}SECURITY WARNING: Available \`${name}\` executable \`${(q)exe}\` is not secure!${unfmt}"

         if { ! file-is-owned-by-me-or-root $exe } {
            echo-err "${errfmt}    - The file is not owned by you, nor is it owned by the root user.${unfmt}"
         }

         if { ! file-is-not-writable-to-others $exe } {
            echo-err "${errfmt}    - The file can be modified by users other than its owner.${unfmt}"
         }
      }

      if (( ${#insecure_exes} > 0 && ${#secure_exes} > 0 )) {
         echo-err "${infofmt}However, the following \`${name}\` executables do appear to be decently secure:${unfmt}"

         for exe ($secure_exes) {
            echo-err "${infofmt}    - ${(q)exe}${unfmt}"
         }

         if [[ $fail_type == '-e' ]] {
            echo-err "${infofmt}Until this security issue is fixed, try using one of the more secure executables.${unfmt}"
         }
      } elif (( ${#insecure_exes} > 0 )) {
         echo-err "${errfmt}Unfortunately, there do not appear to be any secure \`${name}\` executables available.${unfmt}"
      }
   }

   if { [[ $fail_type == '-e' ]] && (( ${#insecure_exes} > 0 )) } {
      return 1
   }

   readonly exe=${secure_exes[1]-}

   if [[ -n $exe ]] {
      echo-raw $exe
      return $?
   } else {
      return 1
   }
}

function run-by-unambiguous-basename {
   emulate -L zsh; set -u

   (( $# >= 1 )) || {
      echo-help 'Usage: run-by-unambiguous-basename <command> [<argument>...]

Runs <command> by basename alone, in an environment where the directory
wherein <command> resides is the only directory in the `PATH`.

<command> may be either:
  - a path to an executable, or
  - the basename of an executable, to be looked up in the (unaltered) `PATH`.'
      return 2
   }

   readonly cmd=$1

   executable-exists $cmd || {
      echo-err "error: command not found: $cmd"
      return 100
   }

   readonly exe==$cmd

   local -a path

   path=(${exe:h})

   command ${exe:t} ${@:2}
}

function run-secure-base {
   emulate -L zsh; set -u

   (( $# >= 1 )) || {
      echo-help 'Usage: run-secure-base <command> [<argument>...]'
      return 2
   }

   run-by-unambiguous-basename $(select-secure-executable -w $1 +) ${@:2}
}

function run-coreutil {
   emulate -L zsh; set -u

   (( $# >= 1 )) || {
      echo-help 'Usage: run-coreutil <name> [<argument>...]'
      return 2
   }

   readonly cmdname=$1
   local cmd=''
   local -a args

   args=(${@:2})

   # Here at least, prefer GNU coreutils. If GNU coreutils are not
   # available, use whatever is available.
   if {have-GNU-system} {
      cmd=$cmdname
   } elif {have-MacPorts-GNU-coreutil $cmdname} {
      cmd=$(path-to-MacPorts-GNU-coreutil $cmdname)
   } else {
      cmd=$cmdname
   }

   executable-exists $cmd || {
      echo-err "error: command not found: $cmdname"
      return 100
   }

   cmd=$(select-secure-executable -w $cmdname =$cmd +)

   if [[ -n $cmd ]] {
      run-by-unambiguous-basename $cmd $args
   } else {
      return 101
   }
}

function have-GNU-coreutil {
   (( $# == 1 )) || {
      echo-help 'Usage: have-GNU-coreutil <name>'
      return 2
   }

   { have-GNU-system && cmd-exists $1 } ||
      have-MacPorts-GNU-coreutil $1
}

function have-MacPorts-GNU-bin {
   have-MacPorts &&
      [[ -d '/opt/local/libexec/gnubin' ]]
}

function have-MacPorts-GNU-coreutil {
   (( $# == 1 )) || {
      echo-help 'Usage: have-MacPorts-GNU-coreutil <name>'
      return 2
   }

   have-MacPorts-GNU-bin &&
      [[ -x "/opt/local/bin/g${1}" ]] &&
      [[ -x "/opt/local/libexec/gnubin/${1}" ]]
}

function path-to-MacPorts-GNU-coreutil {
   echo-raw "/opt/local/libexec/gnubin/${1}"
}

function alias-secure-base {
   (( $# == 2 )) || {
      echo-help 'Usage: alias-secure-base <name> <command...>'
      return 2
   }

   eval "
      function ${(q-)1} {
         run-secure-base ${@:2} \$@
      }
   "
}

mark-time 'initial functions'

#}}}
#{{{ Safety checks

function assert-file-security-property {
   (( $# == 5 )) || {
      echo-help 'usage: assert-file-security-property (W|E) <predicate> <file> <file description> <error description>'
      return 2
   }

   readonly type=$1 predicate=$2 f=$3 fdesc=$4 errdesc=$5

   eval "() { $predicate ${(q)f} }" &&
      return 0

   local z=''
   if [[ $0 =~ -zsh ]] {
      z="$0: "
   }

   local type_str=''
   case $type {
      (E) type_msg='ERROR';;
      (W) type_msg='WARNING';;
   }

   echo-err -n "${z}SECURITY ${type_msg}: $fdesc"' ('"${(q-)f}"') '"$errdesc"
   echo-err "${z:+ Aborting.}"

   return 1
}

function assert-file-is-owned-by-me-or-root {
   (( $# == 2 )) || {
      echo-err 'usage: assert-file-is-owned-by-me-or-root <file> <description>'
      return 2
   }

   assert-file-security-property E \
      file-is-owned-by-me-or-root $1 $2 \
      'is not owned either by you or by the root user!'
}

function assert-file-is-not-writable-to-others {
   (( $# == 2 )) || {
      echo-err 'usage: assert-file-is-not-writable-to-others <file> <description>'
      return 2
   }

   assert-file-security-property E \
      file-is-not-writable-to-others $1 $2 \
      'can be modified by users other than you!'
}

function assert-file-is-not-accessible-to-others {
   (( $# == 2 )) || {
      echo-err 'usage: assert-file-is-not-accessible-to-others <file> <description>'
      return 2
   }

   assert-file-security-property E \
      file-is-not-accessible-to-others $1 $2 \
      'can be accessed by users other than you!'
}

function assert-file-is-secure {
   (( $# == 2 )) || {
      echo-err 'usage: assert-file-is-secure <file> <description>'
      return 2
   }

   assert-file-is-owned-by-me-or-root $1 $2
   assert-file-is-not-writable-to-others $1 $2
}

function assert-file-is-private {
   (( $# == 2 )) || {
      echo-err 'usage: assert-file-is-secure <file> <description>'
      return 2
   }

   assert-file-is-owned-by-me-or-root $1 $2
   assert-file-is-not-accessible-to-others $1 $2
}

mkdir -p ~/.zsh/var

setopt NoFunctionArgZero

assert-file-is-secure ~           'Your `$HOME` directory'         || return 1
assert-file-is-secure $ZSHRC_PATH 'This `zshrc` script'            || return 1
assert-file-is-secure ~/.zsh      'Your zsh settings directory'    || return 1
assert-file-is-secure ~/.zsh/var  'Your zsh data directory'        || return 1

module_path=(${^module_path}(N))
for d ($module_path) {
   assert-file-is-secure $d  'A zsh `$module_path` directory' || return 1
}

fpath=(${^fpath}(N))
for d ($fpath) {
   assert-file-is-secure $d  'A zsh `$fpath` directory'       || return 1
}

setopt FunctionArgZero

mark-time 'safety checks'

#}}}
#{{{ Modules

function zshrc-load-module {
   emulate -L zsh; set -u

   (( $# == 1 )) || {
      echo-help 'usage: zshrc-load-module <module>'
      return 2
   }

   readonly m=$1

   readonly f=$(path-lookup [ -r $m.{so,bundle,sl} ] $module_path)

   [[ -n $f ]] || {
      echo-err "error: ${(q-)m} not found in "'$module_path'
      return 1
   }

   assert-file-is-secure $f 'A zsh module' || return 4

   [[ ${modules[$m]-} != loaded ]] || return 3

   zmodload $m
}

for d ($module_path) {
   for f ($d/zsh/**/(*~example).(so|bundle|sl)) {
      zshrc-load-module ${${f#$d/}:r}
   }
}

mark-time 'module loading'

#}}}
#{{{ Shell parameters

autoload -Uz colors && colors

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh/var/history

# Report timing information (like `time`) for all commands that run for at
# least 16 seconds (of CPU time?).
REPORTTIME=16

# Do not attempt to spelling-correct words to words beginning with U+002E FULL
# STOP (e.g., the names of dotfiles) or with U+005F LOW LINE (which are mainly
# the names of internal (e.g., completion) functions).
CORRECT_IGNORE='[._]*'
CORRECT_IGNORE_FILE='[._]*'

#{{{ *_POSSIBILITIES

local -a \
   EDITOR_POSSIBILITIES \
   PAGER_POSSIBILITIES \
   MANPAGER_POSSIBILITIES \
   BROWSER_POSSIBILITIES \
   CC_POSSIBILITIES \
   CXX_POSSIBILITIES \

EDITOR_POSSIBILITIES=(
   'nano' 'vim' 'nvi' 'elvis' 'vi' 'pico' 'emacs' 'joe' 'jed' 'ed'
   ${EDITOR-})
PAGER_POSSIBILITIES=(
   'most' 'less' 'more' 'cat'
   ${PAGER-})
MANPAGER_POSSIBILITIES=(
   'most' 'less' 'more' 'cat'
   ${MANPAGER-})
BROWSER_POSSIBILITIES=(
   'elinks' 'w3m' 'lynx' 'links'
   ${BROWSER-})
CC_POSSIBILITIES=(
   'clang' 'gcc' 'cc'
   ${CC-})
CXX_POSSIBILITIES=(
   'clang++' 'g++' 'c++'
   ${CXX-})

#}}}

export EDITOR=$(first-cmd-of $EDITOR_POSSIBILITIES)
export SLANG_EDITOR='vim %s +%d'
export PAGER=$(first-cmd-of $PAGER_POSSIBILITIES)
export MANPAGER=$(first-cmd-of $MANPAGER_POSSIBILITIES)
export BROWSER=$(first-cmd-of $BROWSER_POSSIBILITIES)
export CC=$(first-cmd-of $CC_POSSIBILITIES)
export CXX=$(first-cmd-of $CXX_POSSIBILITIES)
export MACOSX_DEPLOYMENT_TARGET=10.6
export LS_COLOR=yes
export CCACHE_COMPRESS=yes
# <http://petereisentraut.blogspot.com/2011/09/ccache-and-clang-part-2.html>
export CCACHE_CPP2=yes
# Chicken Scheme Compiler
export CSC_OPTIONS='-cc cc -cxx c++ -ld c++'
export AUTOSSH_PORT=0

KEYTIMEOUT=25
READNULLCMD=$PAGER

#{{{ LS_COLORS, LSCOLORS

export LS_COLORS="${${$(echo "
   # reset
   rs=${color[none]}
   # normal (is this different from 'fi'?)
   no=${color[none]}
   # file
   fi=${color[none]}
   # file with reference count > 1 (multiple hardlinks)
   mh=${color[underline]}
   # file that is executable
   ex=${color[red]}
   # file that is setuid (u+s)
   su=${color[bg-red]}
   # file that is setgid (g+s)
   sg=${color[bg-cyan]}
   # file with capability
   ca=${color[bg-magenta]}
   # directory
   di=${color[cyan]}
   # directory that is sticky (+t)
   st=${color[bold]};${color[cyan]};${color[bg-blue]}
   # directory that is other-writable (o+w)
   ow=${color[bold]};${color[cyan]};${color[bg-yellow]}
   # directory that is sticky and other-writable
   tw=${color[bold]};${color[cyan]};${color[bg-green]}
   # symbolic link
   ln=${color[magenta]}
   # symbolic link with missing target (orphan)
   or=${color[bold]};${color[underline]};${color[blink]};${color[cyan]};${color[bg-magenta]}
   # missing target of orphan symbolic link (shown by, e.g., 'ls -l')
   mi=${color[bold]};${color[underline]};${color[magenta]};${color[bg-cyan]}
   # pipe
   pi=${color[bold]};${color[yellow]}
   # socket
   so=${color[bold]};${color[green]}
   # door (from Solaris?)
   do=${color[bold]};${color[red]}
   # block device
   bd=${color[standout]};${color[green]}
   # character device
   cd=${color[standout]};${color[yellow]}
")//[[:space:]]#[#][^
]#[[:space:]]#/:}#:}:"

export LSCOLORS="${${$(echo "
   # directory (cyan, default: blue)
   gx
   # symbolic link (default magenta)
   fx
   # socket (bold green, default: green)
   Cx
   # pipe (bold brown/yellow, default: brown)
   Dx
   # executable (default red)
   bx
   # block special (white on green, default: blue on cyan)
   Hc
   # character special (white on brown/yellow, default: blue on brown)
   HD
   # setuid executable (default black on red)
   ab
   # setgid executable (default black on cyan)
   ag
   # sticky other-writable directory (bold cyan on green, default: black
   # on green)
   Gc
   # non-sticky other-writable directory (bold cyan on brown/yellow,
   # default: black on brown)
   GD
")//[[:space:]]#[#][^
]#[[:space:]]#/}#}"

#}}}

# `git-hub` shell environment setup
if [[ -e ~/src/git-hub ]] {
   assert-file-is-secure ~/src/git-hub \
         'The `git-hub` source directory' &&
      assert-file-is-secure ~/src/git-hub/init \
         'The `git-hub` shell environment set-up script' &&
      source ~/src/git-hub/init
}

# De-duplicate any duplicate elements that may have been introduced into the
# lookup path arrays (which somehow does happen, despite them being declared
# `-aU` in my `~/.zshenv`.
typeset -U path fpath manpath

#{{{ Filter lookup path arrays for security.

# Only include directories that are not (group- or) other-writable...
   path=(   ${^path}(N/f[o-w]) )
manpath=(${^manpath}(N/f[o-w]) )
  fpath=(  ${^fpath}(N/f[go-w]))
# ...and are owned by the current user or by root.
   path=(   ${^path}(NU)     ${^path}(Nu0))
manpath=(${^manpath}(Nu0) ${^manpath}(NU) )
  fpath=(  ${^fpath}(NU)    ${^fpath}(Nu0))

#}}}

mark-time 'shell parameters'

#}}}
#{{{ Shell prompts

precmd_functions=(
   save-cmd-exit-status-code
   $precmd_functions
   set-dynamic-prompts
)

export ZSHRC_ANON_PROMPT=$ZSHRC_ANON_PROMPT
export ZSHRC_PROMPT_SIGIL='%#'
export ZSHRC_NO_RPROMPT=$ZSHRC_NO_RPROMPT

# Disabled because it interferes with completion menus.
integer ZSHRC_ENABLE_PROMPT_REFRESH=0

readonly ZSHRC_default_TIMEFMT=$TIMEFMT

#{{{ ZSHRC_PROMPT_STYLE

local -A ZSHRC_PROMPT_STYLE
local ZSHRC_PROMPT_STYLE_FILE=~/.zsh/prompt-style

if [[ -e $ZSHRC_PROMPT_STYLE_FILE ]] {
   assert-file-is-secure $ZSHRC_PROMPT_STYLE_FILE \
      'The prompt style configuration file' &&
         ZSHRC_PROMPT_STYLE=($(<~/.zsh/prompt-style))
}

() {
   local k v
   for k v (
      main '%B%F{blue}'
      info '%B%F{blue}'
      misc '%F{cyan}'
      clock '%B%F{blue}'
      clock-fmt '%F %T'
      prompt-sigil '%B%F{green}'
      prompt-sigil-special '${ZSHRC_PROMPT_STYLE[prompt-sigil]-}'
      select-prompt '${ZSHRC_PROMPT_STYLE[prompt-sigil]-}'
      cmd-success '%B%F{blue}'
      cmd-failure '%B%F{red}'
      #cmd-exit-status-code-radix 10
      spell-old '${ZSHRC_PROMPT_STYLE[info]-}'
      spell-new '${ZSHRC_PROMPT_STYLE[info]-}'
      debug-trace '%F{red}'
      #misc-info '%L'
      #unicode yes
   ) {
      if (( ! ${+ZSHRC_PROMPT_STYLE[$k]} )) {
         eval 'ZSHRC_PROMPT_STYLE[$k]="'"$v"'"'
      }
   }
}

#}}}
#{{{ set-dynamic-prompts

function set-dynamic-prompts {
   # Prompts:
   # host user % cmd                                                  PS1
   # ·· Correct ‘cmd’ to ‘dmd’? [(y)es|(n)o|(a)bort|(e)dit]       SPROMPT
   # ········· % expectation > continuation                           PS2
   # ···· menu #> selection                                           PS3

   # The functions of this function could presumably also be performed
   # with the `PROMPT_SUBST` option and all operations implemented in
   # terms of global parameters and prompting-time parameter expansions
   # in prompt strings, but such an implementation would presumably have
   # disadvantages in readability.

   local -A pstyle
   pstyle=(${(kv)ZSHRC_PROMPT_STYLE})

   readonly unicode_okay=${pstyle[unicode]-${ZSHRC_UNICODE:+yes}}

   readonly hostname=${(q-)HOST%.local} username=${(q-)USERNAME}

   if [[ -n $ZSHRC_ANON_PROMPT ]] {
      hostname=''
      username=''
   }

   if [[ -n ${pstyle[hostname-override]-} ]] {
      hostname=${pstyle[hostname-override]}
   }

   if [[ -n ${pstyle[username-override]-} ]] {
      username=${pstyle[username-override]}
   }

   readonly hostuser_info="${hostname}${hostname:+ }${username}${username:+ }"

   readonly cwd_info="${pstyle[info]-}%~%b%f "

   # Main prompt.
   PS1="${pstyle[main]-}${hostuser_info}${ZSHRC_NO_RPROMPT:+${cwd_info}}%b%f%(!.${pstyle[prompt-sigil-special]-}.${pstyle[prompt-sigil]-})${ZSHRC_PROMPT_SIGIL}%b%f "

   local prev_cmd_status=''

   local exit_success_char='—'

   if [[ $unicode_okay != yes ]] {
      exit_success_char='-'
   }

   readonly exit_status_radix=${pstyle[cmd-exit-status-code-radix]-}
   local exit_success_mark="${exit_success_char}${exit_success_char}"
   local exit_failure_fmtspec='!!'

   case $((exit_status_radix)) {
      (16)
         exit_failure_fmtspec='%02X'
         ;;
      (10)
         exit_failure_fmtspec='%03d'
         exit_success_mark+=${exit_success_char}
         ;;
      (8)
         exit_failure_fmtspec='%03o'
         exit_success_mark+=${exit_success_char}
         ;;
   }

   if (( ZSHRC_LAST_CMD_EXIT_STATUS_CODE == 0 )) {
      prev_cmd_status="${pstyle[cmd-success]-}${exit_success_mark}"
   } else {
      prev_cmd_status="${pstyle[cmd-failure]-}$(
         printf ${exit_failure_fmtspec} \
            $ZSHRC_LAST_CMD_EXIT_STATUS_CODE)"
   }

   readonly prompt_clock="%D{${pstyle[clock-fmt]-}}"

   readonly misc_info=${pstyle[misc-info]-}

   # Main prompt, right-hand side.
   typeset -g RPS1="${cwd_info}${prev_cmd_status}%b%f ${pstyle[clock]-}${prompt_clock}%b%f${misc_info:+ }${pstyle[misc]}${misc_info}%b%f"

   if [[ -n $ZSHRC_NO_RPROMPT ]] {
      RPS1=''
   }

   # Line continuation prompt.
   typeset -g PS2="${pstyle[info]-} %b%f${pstyle[prompt-sigil]}%#%b%f ${pstyle[info]}%_%b%f ${pstyle[prompt-sigil]}>%b%f "

   # Line continuation prompt, right-hand side.
   typeset -g RPS2="${pstyle[info]-}${prompt_clock}${misc_info:+ }${misc_info}%b%f"

   # `select` prompt.
   typeset -g PS3="${pstyle[select-prompt]-} menu #>%b%f "

   # Debug trace prefix.
   typeset -g PS4="${pstyle[debug-trace]-}%N:%i %B*%b%f "

   local spl_old="‘%b%f${pstyle[spell-old]-}%R%b%f${pstyle[info]-}’"
   local spl_new="‘%b%f${pstyle[spell-new]-}%r%b%f${pstyle[info]-}’"

   if [[ $unicode_okay != yes ]] {
      spl_old=${spl_old//[‘’]/\`}
      spl_new=${spl_new//[‘’]/\`}
   }

   # Spelling-correction prompt.
   typeset -g SPROMPT="${pstyle[info]-} Correct $spl_old to $spl_new? [%Uy%ues|%Un%uo|%Ua%ubort|%Ue%udit]%b%f "

   # If the terminal does not support underlines (as far as zsh knows),
   # mark the letters to press at a spelling-correction prompt with
   # parentheses instead.
   if [[ -z ${(%):-'%U%u'} ]] {
      SPROMPT=${${SPROMPT//\%U/(}//\%u/)}
   }

   # Align prompts.

   local spacing_char='·'

   if [[ $unicode_okay != yes ]] {
      spacing_char='-'
   }

   readonly prompt_space="${${hostuser_info% }//?/${spacing_char}}"
   readonly end_sp=${hostuser_info:+ }

   PS2="${PS2/ /${prompt_space}${end_sp}}"
   PS3="${PS3/ /${prompt_space%?????}${end_sp}}"
   SPROMPT="${SPROMPT/ /${prompt_space%???????}${end_sp}}"

   # `time`/`REPORTTIME` report format

   # Because, in the current format of the `prompt-style` file, the
   # values of entries cannot contain whitespace, the following
   # translations will be performed on the value of a `time-report-fmt`
   # entry in the `prompt-style` file:
   #
   #   - Low-lines not enclosed in parentheses (`_`) will be translated
   #     to spaces.
   #
   #   - Low-lines enclosed in parentheses (`(_)`) will be translated to
   #     horizontal tabs.
   #
   # Furthermore, because UTF-8–encoded non–US-ASCII Unicode code-points
   # are not presently supported in `TIMEFMT` (see also the function
   # `have-zsh-supporting-Unicode-TIMEFMT`), the following translations
   # will also be performed on the value of a `time-report-fmt` entry in
   # the `prompt-style` file unless UTF-8–encoded non–US-ASCII Unicode
   # code-points appear to be supported in `TIMEFMT`:
   #
   #   - Typographical single quotation marks (`‘`, `’`) will be
   #     translated to grave accents (`` ` ``).
   #
   #   - Typographical double quotation marks (`“`, `”`) will be
   #     translated to straight double quotation marks (`"`).
   #
   #   - Em-dashes (`—`) will be translated to double hyphen-minuses
   #     (`--`).

   local time_fmt=${pstyle[time-report-fmt]-}

   if [[ -n $time_fmt ]] {
      # A low-line (`_`) may be used in the `time-report-fmt` to
      # represent a space, because, in the present format of the
      # `prompt-style` file, values cannot contain spaces.
      #
      # A low-line that is enclosed in parentheses (`(_)`) instead
      # represents a horizontal tab.
      time_fmt=${${time_fmt//\(_\)/$'\t'}//_/ }
   } else {
      time_fmt=$ZSHRC_default_TIMEFMT
   }

   if { [[ $unicode_okay != yes ]] ||
         ! have-zsh-supporting-Unicode-TIMEFMT} {
      # If Unicode is not supported, then degrade
      #   - typographical single quotation marks into grave accents,
      #   - typographical double quotation marks into plain
      #     quotation marks, and
      #   - em-dashes into double hyphen-minuses.
      time_fmt=${${${time_fmt//[‘’]/\`}//[“”]/\"}//—/--}
   }

   typeset -g TIMEFMT="${(%)pstyle[info]-}time: ${time_fmt}${(%):-%b%f}"
}

#}}}
#{{{ zsh-prompt-refresh
function zsh-prompt-refresh {
   emulate -L zsh; set -u

   zmodload zsh/sched

   if { [[ ${1-} != 'sched-only' ]] &&
         (( $ZSHRC_ENABLE_PROMPT_REFRESH )) && zle } {
      zle reset-prompt
   }

   readonly rr=${ZSHRC_PROMPT_STYLE[refresh-rate]-}

   if [[ $rr == <1-> ]] {
      sched +$rr zsh-prompt-refresh
   } elif [[ $rr == 'standby' ]] {
      sched +3 zsh-prompt-refresh
   }
}

run-at-shell-entry 'zsh-prompt-refresh sched-only'
#}}}

mark-time 'shell prompts'

#}}}
#{{{ Command running-time reporting

preexec_functions+=cmd-running-time-reporting-preexec
precmd_functions+=cmd-running-time-reporting-postexec

local REPORTTIME_TYPE=${REPORTTIME_TYPE:-both}
local REPORTTIME_LENGTHY=-1
local -aU REPORTTIME_LENGTHY_COMMANDS

REPORTTIME_LENGTHY_COMMANDS=(
   $EDITOR_POSSIBILITIES
   $PAGER_POSSIBILITIES
   $MANPAGER_POSSIBILITIES
   $BROWSER_POSSIBILITIES
)

local -F ZSHRC_last_cmd_preexec_time
local ZSHRC_cmd_running_time_report_threshold
local ZSHRC_cmd_running_time_REPORTTIME_save
integer ZSHRC_cmd_running_time_ready=0

function cmd-running-time-reporting {
   case "$*" {
      (help)
         echo-help 'Command Running-time Reporting System Help

The command running-time reporting system modifies the behavior of the special
shell parameter `REPORTTIME`, depending on the value of the shell parameter
`REPORTTIME_TYPE`, which may be `cpu-time`, `run-time`, or `both`.

When `$REPORTTIME_TYPE` is `cpu-time`, the behavior of `REPORTTIME` will be
left at its default, which is to report running-time information for any
command that occupies at least `$REPORTTIME` seconds of CPU time.

When `$REPORTTIME_TYPE` is `run-time`, for any command that runs for at least
`$REPORTTIME` seconds, regardless of how much time the command spent actively
consuming CPU power, the total running-time of that command will be reported.

When `$REPORTTIME_TYPE` is `both`, both the `cpu-time` and `run-time`
behaviors will be enabled. This is the default.

For any command listed in the array parameter `REPORTTIME_LENGTHY_COMMANDS`,
`$REPORTTIME_LENGTHY` will be used rather than `$REPORTTIME`. By default,
`REPORTTIME_LENGTHY_COMMANDS` contains the names of several common text
editors, pagers, and HTML viewers/Web browsers. `REPORTTIME_LENGTHY` defaults
to `-1`.

Because this system is overly complicated, if you want to set `REPORTTIME`
after shell initialization, you should use the `set-REPORTTIME` shell
function rather than setting `REPORTTIME` directly.'
         return 0
         ;;
      (*)
         echo-help 'Usage: cmd-running-time-reporting (help)'
         return 2
         ;;
   }
}

function set-REPORTTIME {
   emulate -L zsh; set -u

   { (( $# == 1 )) && [[ $1 == <-> ]] } || {
      echo-help 'Usage: set-REPORTTIME <integer>'
      return 2
   }

   REPORTTIME=$1
   ZSHRC_cmd_running_time_REPORTTIME_save=$1
}

function cmd-running-time-reporting-preexec {
   ZSHRC_cmd_running_time_REPORTTIME_save=${REPORTTIME-}

   local threshold

   if {array-contains ${${2-}%% *} $REPORTTIME_LENGTHY_COMMANDS} {
      threshold=${REPORTTIME_LENGTHY-}
      typeset -g REPORTTIME=$threshold
   } elif [[ ${${2-}%% *} == 'without-REPORTTIME' ]] {
      threshold=-1
   } else {
      threshold=${REPORTTIME-}
   }

   typeset -g ZSHRC_cmd_running_time_report_threshold=${threshold:-0}

   typeset -g REPORTTIME_TYPE=${REPORTTIME_TYPE:-both}

   if [[ $REPORTTIME_TYPE == 'run-time' ]] {
      typeset -g REPORTTIME=-1
   }

   ZSHRC_cmd_running_time_ready=1

   typeset -g ZSHRC_last_cmd_preexec_time=${SECONDS:-0}
}

function cmd-running-time-reporting-postexec {
   readonly elapsed_time=$(( SECONDS - ZSHRC_last_cmd_preexec_time ))

   typeset -g REPORTTIME_TYPE=${REPORTTIME_TYPE:-both}

   if [[ -n $ZSHRC_cmd_running_time_REPORTTIME_save ]] {
      typeset -g REPORTTIME=$ZSHRC_cmd_running_time_REPORTTIME_save
   }

   if (( ! ZSHRC_cmd_running_time_ready )) {
      return
   }

   if [[ $REPORTTIME_TYPE == (run-time|both) ]] {
      if (( elapsed_time >=
            ZSHRC_cmd_running_time_report_threshold &&
         ZSHRC_cmd_running_time_report_threshold >= 0
      )) {
         zshrc-chirp-toned printf \
            'total command running-time: %f s\n' \
            $elapsed_time
      }
   } elif [[ $REPORTTIME_TYPE != 'cpu-time' ]] {
      echo-err 'error: `$REPORTTIME_TYPE` should be `run-time`, `cpu-time`, or `both`. (Try running `cmd-running-time-reporting help` for help.)'
   }

   ZSHRC_cmd_running_time_ready=0
}

#}}}
#{{{ Functions and aliases

alias-secure-base fgrep 'grep -F'
alias-secure-base egrep 'grep -E'
alias-secure-base ln 'ln -i'
alias-secure-base cp 'cp -i'
alias-secure-base mv 'mv -i'
alias-secure-base rm 'rm -I'
#alias-secure-base git 'TZ=UTC git'
alias-secure-base ffmpeg 'ffmpeg -v warning'
alias-secure-base ffplay 'ffplay -v warning'
alias source-zshrc='source ~/.zshrc'
#alias cat='echo "\`cat\` has been disabled for security reasons [<https://security.stackexchange.com/a/56309>]; try \`$PAGER\` instead."'
alias-secure-base cat 'cat -v'
alias-secure-base gpg2 'gpg2'

function ls {
   local -a ls_cmd gnu_ls_opts
   local color_opt

   gnu_ls_opts=(
      --classify --escape --human-readable --time-style='+%F %T'
      -v
   )

   if { have-GNU-system } {
      # Use default (GNU) `ls`.
      ls_cmd=(=ls $gnu_ls_opts)
      color_opt='--color=auto'
   } elif [[ -x '/opt/local/bin/gls' ]] {
      # Use GNU `ls` installed via MacPorts.
      ls_cmd=('/opt/local/bin/gls' $gnu_ls_opts)
      color_opt='--color=auto'
   } else {
      # Use default (non-GNU, hopefully BSD-compatible) `ls`.
      ls_cmd=(=ls -bFhT)
      color_opt='-G'
   }

   if [[ $LS_COLOR == yes ]] {
      ls_cmd+=$color_opt
   }

   run-secure-base $ls_cmd $@
}

function la {
   ls -A $@
}

function ll {
   ls -al $@
}

function lr {
   ls -Rl $@
}

function lx {
   if {have-GNU-coreutil ls} {
      ls --context -l $@
   } else {
      ls '-@elO' $@
   }
}

function llwhich {
   ll $(which-if-any $@)
}

function vp {
   if (( $# )) {
      view $@
   } else {
      vim-pager
   }
}

function ag {
   run-secure-base ag $@ | run-secure-base cat -v
}

function newdir {
   (( $# == 1 )) || {
      echo 'usage: newdir <name of new directory>
Creates a new directory and `cd`s into it.'
      return 2
   }

   mkdir $1 && cd $1
}

function ssh {
   # `autossh`, but the completion facilities should think that it’s
   # `ssh`, and complete for it as such.

   readonly cmd=$(select-secure-executable -w ssh \
      $(which-if-any -ap autossh) $(which-if-any -ap ssh))

   if [[ -z $cmd ]] {
      echo-err 'error: No suitable `ssh` or `autossh` command found.'
      return 100
   }

   run-secure-base $cmd $@
}

function gpg {
   readonly cmd=$(select-secure-executable -w gpg \
      $(which-if-any -ap gpg2) +)

   if [[ -z $cmd ]] {
      echo-err 'error: No suitable `gpg2` or `gpg` command found.'
      return 100
   }

   run-secure-base $cmd $@
}

function wiktionary {
   without-REPORTTIME run-secure-base wiktionary
}

function showterm {
   in-ghost-shell run-secure-base showterm
}

function asciinema {
   in-ghost-shell run-secure-base asciinema
}

function vim-ghost {
   vim -u NONE -i NONE -n --cmd 'source ~/.vim/vimrc-ghost.vim' $@
}

function vim-encrypt {
   vim-ghost -x $@
}

function clang+++ {
   clang++ -std=c++11 -stdlib=libc++ -Weverything -Werror \
      -Wno-c++98-compat -Wno-c++98-compat-pedantic $@
}

function dmd+ {
   dmd -de -O -fPIC -w $@
}

function csc+ {
   csc -O5 -explicit-use $@
}

function ffinfo {
   ffprobe -v warning $@ -v info
}

function line {
   set -u

   [[ ($# == 1 || $# == 2) && ${1-} == <-> &&
         ($# == 1 || ${2-} == <->) ]] || {
      echo-help 'Usage: line <number> [<end-number>]

Print, to the standard output stream, the <number>-th line of the standard
input stream (with line-numbering beginning at 1, not at 0).

If <end-number> is specified, print not only the <number>-th line, but also:
  - any lines between the <number>-th line and the <end-number>-th, and
  - the <end-number>-th line.

If <end-number> is specified, it must be greater than or equal to <number>.'
      return 2
   }

   (( $1 >= 1 )) || {
      echo-err "error: <number> ($1) must be >= 1"
      return 3
   }

   (( $# == 1 || ${2-0} >= $1 )) || {
      echo-err "error: <end-number> ($2) must be >= <number> ($1)"
      return 4
   }

   (( $# == 1 || ${2-0} >= 1 )) || {
      echo-err "error: <end-number> ($2) must be >= 1"
      return 5
   }

   readonly start_nr=$1 end_nr=${2-$1}
   local line
   integer line_nr=0

   while {read line} {
      if (( ++line_nr >= start_nr )) {
         echo-raw $line
      }

      if (( line_nr >= end_nr )) {
         break
      }
   }
}

function cutcol {
   awk "{print \$$1}"
}

function filesize {
   if [[ $(type -w zstat) == 'zstat: builtin' ]] {
      zstat -n +size $@
   } elif {have-GNU-coreutil stat} {
      run-coreutil stat --format='%s  %n' -- $@
   } else {
      run-secure-base stat -f '%z  $N' $@
   }
}

function filecreationtime {
   if {have-GNU-coreutil stat} {
      run-coreutil stat --format='%w  %n' -- $@
   } else {
      run-secure-base stat -t '%F %T %z' -f '%SB  %N' $@
   }
}

function 7z-a+ {
   7z a -t7z -mtc -mx -m0=LZMA2 $@
}

function chrome-open {
   if {have-Darwin-system} {
      open -a 'Google Chrome' $@
      return
   }

   readonly cmd=$(select-secure-executable -w 'Chromium or Google Chrome' \
      chromium-browser google-chrome)

   if [[ -z $cmd ]] {
      echo-err 'error: No suitable Chromium or Google Chrome executable found.'
      return 100
   }

   run-secure-base $cmd
}

function optipng-max {
   optipng -o7 -zm1-9 $@
}

function imagemagick-avgcolor {
   (( $# == 1 )) || {
      echo 'usage: imagemagick-avgcolor <image>'
      return 2
   }

   convert $1 -scale '1x1!' -format '%[pixel:s]' info:-
   echo
}

function set-prompt-anon {
   case "$*" {
      (yes)
         ZSHRC_ANON_PROMPT=y;;
      (no)
         ZSHRC_ANON_PROMPT=;;
      (get)
         if [[ -n $ZSHRC_ANON_PROMPT ]] {
            echo yes
         } else {
            echo no
         };;
      (*)
         echo 'usage: set-prompt-anon (yes|no|get)
Switch off or on the including of hostname and username in shell prompt.'
   }
}

function without-REPORTTIME {
   readonly r=$REPORTTIME
   REPORTTIME=-1
   $@
   REPORTTIME=$r
}

#function imagebin {
#  # Commented out because imagebin.ca uses a StartSSL certificate, and
#  # has not changed it post-Heartbleed.
#  (( $# == 1 )) || {
#     echo 'usage: imagebin <image file>'
#     return 2
#  }
#  curl -F "file=@$1" 'https://imagebin.ca/upload.php'
#}

function with-anon-prompt {
   readonly ap=$(set-prompt-anon get)
   set-prompt-anon yes
   $@
   set-prompt-anon $ap
}

function with-no-rprompt {
   readonly nr=$ZSHRC_NO_RPROMPT
   ZSHRC_NO_RPROMPT=y
   $@
   ZSHRC_NO_RPROMPT=$nr
}

function with-quiet-zshrc {
   readonly zq=$ZSHRC_QUIET
   ZSHRC_QUIET=y
   $@
   ZSHRC_QUIET=$zq
}

function in-ghost-shell {
   with-quiet-zshrc with-anon-prompt $@
}

function reset-window-title {
   if [[ -n $TMUX ]] {
         # Reset tmux window title.
         echo -n "\ek$ZSH_NAME\e\\"
         # Reset tmux pane title.
         echo -n "\e]2;$ZSH_NAME\e\\"
   }

   if [[ $TERM == *xterm* ]] {
         # Clear title.
         echo -n '\e]0;\a'
   }
}

integer ZSHRC_LAST_CMD_EXIT_STATUS_CODE=0

function save-cmd-exit-status-code {
   ZSHRC_LAST_CMD_EXIT_STATUS_CODE=$?
}

function have-zsh-supporting-Unicode-TIMEFMT {
   emulate -L zsh; set -u

   # [2014-10-27 12:43 -0700] At the present time, including octets with
   # the high bit set (e.g., Unicode code-points not in US-ASCII that are
   # encoded as UTF-8) in `TIMEFMT` results in garbled output from
   # `time`.
   #
   # Mikael Magnusson (Mikachu) submitted a patch to zsh to fix this
   # issue, after I brought the issue up in
   # <ircs://chat.freenode.net/zsh>.

   readonly test_str='‘“Ā–က—𐀀”’'

   [[ $( () {
         readonly TIMEFMT="$test_str"
         time =true
      } 2>&1 ) == "$test_str" ]]
}

function view-zshfn {
   (( $# == 1 )) || {
      echo 'usage: view-zshfn <name>
Open `$PAGER` with the first occurrence of <name> in `$fpath`.'
      return 2
   }

   for dir ($fpath) {
      readonly f="$dir/$1"

      if [[ -e $f ]] {
         if [[ -r $f ]] {
            $PAGER $f
            break
         } else {
            echo-err "\`${(q)f}\` is not readable; skipping it...."
         }
      }
   }
}

function test-italics {
   # <https://code.google.com/p/iterm2/issues/detail?id=391#c12>
   echo "$(tput sitm)italics$(tput ritm) $(tput smso)standout$(tput rmso)"
}

function test-xterm256colors {
   for c ({0..255}) {
      printf "\e[38;5;${c}m\e[48;5;${c}m%5d  █%s" $c $reset_color
      (( ($c % 10) == 9 )) && echo
   }
   echo $reset_color
}

function test-busyloop {
   emulate -L zsh; set -u
   setopt KshGlob

   { (( $# == 1 )) && [[ $1 == <->?(.<->) ]] } || {
      echo-help 'Usage: test-busyloop <duration in seconds>'
      return 2
   }

   readonly end_time=$(( SECONDS + $1 ))

   while (( SECONDS < end_time )) {}
}

mark-time 'functions and aliases'

#}}}
#{{{ Key bindings

function _call-base-widget-with-buffer {
   zle .${WIDGET%-buffer} $BUFFER
}

# In the backward incremental history search triggered with `^R`, have the
# initial search pattern be what’s already been typed on the command-line, if
# anything, rather than the empty string.
#
# From <ircs://chat.freenode.net/zsh>, 2014-06-26 12:30–13:27 UTC.
#
# (See also the requisite line in `bindkey-addc74d`, below.)
zle -N history-incremental-pattern-search-backward-buffer \
   _call-base-widget-with-buffer
bindkey -M isearch '^R' history-incremental-pattern-search-backward-buffer

zle -N insert-unicode-char

function bindkey-addc74d {
   bindkey -M $1 '^[[H' vi-beginning-of-line # Home
   bindkey -M $1 '^[[1;2H' vi-first-non-blank # Shift+Home
   bindkey -M $1 '^[[F' vi-end-of-line # End
   bindkey -M $1 '^[[1;5D' vi-backward-word # Control+Left
   bindkey -M $1 '^[[1;5C' vi-forward-word # Control+Right
   bindkey -M $1 '^[[1;6C' vi-forward-word-end # Shift+Control+Right
   bindkey -M $1 '^[[1;9D' vi-backward-blank-word # Alt+Left
   bindkey -M $1 '^[[1;9C' vi-forward-blank-word # Alt+Right
   bindkey -M $1 '^[[1;10C' vi-forward-blank-word-end # Shift+Alt+Right
   bindkey -M $1 '^[[A' up-line-or-history # Up
   bindkey -M $1 '^[[B' down-line-or-history # Down
   bindkey -M $1 '^[[1;9A' up-line-or-search # Alt+Up

   bindkey -M $1 '^R' history-incremental-pattern-search-backward-buffer
}

function bindkey-newc74d {
   bindkey -N $1 $2
   bindkey-addc74d $1
}

bindkey-newc74d c74d-emacs emacs
bindkey-newc74d c74d-viins viins
bindkey-newc74d c74d-vicmd vicmd

bindkey -M c74d-vicmd '#' vi-pound-insert

bindkey -A c74d-emacs main

mark-time 'key bindings'

#}}}
#{{{ Completion

integer ZSHRC_USE_COMPLETION_CACHE=1

fpath=(~/.zsh/completion $fpath)

zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' expand suffix
zstyle ':completion:*' file-sort name
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-suffixes yes
zstyle ':completion:*' matcher-list '' '+m:{[:lower:]}={[:upper:]}' '+r:|[._-]=* r:|=*' '+l:|=* r:|=*'
zstyle ':completion:*' menu yes select interactive
zstyle ':completion:*' preserve-prefix '//[^/]##/'
zstyle ':completion:*' remote-access no
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*' squeeze-slashes yes
zstyle ':completion:*' verbose yes
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin \
                                           /usr/local/bin  \
                                           /usr/sbin       \
                                           /usr/bin        \
                                           /sbin           \
                                           /bin            \
                                           /usr/X11/bin
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

autoload -Uz compinit
() {
   local d=''
   if (( ! $ZSHRC_USE_COMPLETION_CACHE )) {
      d='-D'
   }
   if { is-zsh-fn compinit } {
      compinit -d ~/.zsh/var/completion-cache $d
      _comp_options+='NO_POSIX_IDENTIFIERS'
   }
}

mark-time 'completion'

#}}}
#{{{ Extensions

mark-time 'extensions'

#}}}
#{{{ Delayed commands

for cmd ($ZSHRC_run_at_shell_entry) {
   eval $cmd
}

mark-time 'delayed commands'

#}}}
#{{{ `zshrc.local`

readonly LOCAL_ZSHRC_PATH=~/.zsh/zshrc.local

() {

if [[ -e $LOCAL_ZSHRC_PATH ]] {
   assert-file-is-secure $LOCAL_ZSHRC_PATH 'Your `zshrc.local` script' ||
      return 3

   [[ -r $LOCAL_ZSHRC_PATH ]] || {
      echo-err 'error: `'"${(q)LOCAL_ZSHRC_PATH}"'` exists but is not readable.'
      return 4
   }

   source $LOCAL_ZSHRC_PATH
}

}

mark-time 'zshrc.local'

#}}}
#{{{ Timing, end

readonly -F ZSHRC_total_time=$(( $SECONDS - $ZSHRC_start_time ))

if (( ($ZSHRC_total_time - $ZSHRC_mark_time_total) \
      >= $ZSHRC_rc_total_runtime_variance_report_threshold )) {
   mark-time-chirp 'time unrecorded in zshrc' \
      $(( $ZSHRC_total_time - $ZSHRC_mark_time_total))
}

if (( $ZSHRC_total_time >= $ZSHRC_rc_total_runtime_report_threshold )) {
   mark-time-chirp "total zshrc run-time" $ZSHRC_total_time
}

readonly -F ZSHRC_unrecorded_initztn_time=$(($SECONDS \
   - $ZSHRC_mark_time_total))
if (( $ZSHRC_unrecorded_initztn_time \
      >= $ZSHRC_initztn_total_runtime_variance_report_threshold )) {
   mark-time-chirp 'time unrecorded in initialization' \
      $ZSHRC_unrecorded_initztn_time
}

if (( $SECONDS >= $ZSHRC_initztn_total_runtime_report_threshold )) {
   mark-time-chirp 'total initialization run-time' $SECONDS
}

#}}}

set +eu
# vim: expandtab shiftwidth=3
