#!/bin/bash

COLOR_GREEN=$'\033[32m'
COLOR_RED=$'\033[91m'
COLOR_YELLOW=$'\033[93m'
COLOR_RESET=$'\033[00m'

# global ELOG_INDENT
# global ELOG_COLOR_OK
# global ELOG_COLOR_ERROR
# global ELOG_COLOR_QUOTE
# global ELOG_COLOR_RESET

eon() {
    echo "$1" | grep -q -i '^\(1\|yes\|true\|on\)$'
}

eoff() {
    ! eon "$1"
}

einfo() {
    # global ELOG_INDENT
    # global ELOG_COLOR_OK
    # global ELOG_COLOR_RESET
    echo " $ELOG_COLOR_OK*$ELOG_COLOR_RESET$ELOG_INDENT" "$@"
}

eerror() {
    # global ELOG_INDENT
    # global ELOG_COLOR_ERROR
    # global ELOG_COLOR_RESET
    echo " $ELOG_COLOR_ERROR*$ELOG_COLOR_RESET$ELOG_INDENT" "$@" >&2
}

eecho() {
    # global ELOG_INDENT
    echo "  $ELOG_INDENT" "$@"
}

eindent_reset() {
    # global ELOG_INDENT
    ELOG_INDENT=""
}

eindent() {
    # global ELOG_INDENT
    ELOG_INDENT="$ELOG_INDENT  "
}

eoutdent() {
    # global ELOG_INDENT
    [ -n "$ELOG_INDENT" ] && ELOG_INDENT="${ELOG_INDENT::${#ELOG_INDENT}-2}"
}

edie() {
    eerror "$@"
    exit 1
}

elog_enable_colors() {
    ELOG_COLOR_OK="$COLOR_GREEN"
    ELOG_COLOR_ERROR="$COLOR_RED"
    ELOG_COLOR_RESET="$COLOR_RESET"
    ELOG_COLOR_QUOTE="$COLOR_YELLOW"
}

elog_disable_colors() {
    ELOG_COLOR_OK=""
    ELOG_COLOR_ERROR=""
    ELOG_COLOR_RESET=""
    ELOG_COLOR_QUOTE=""
}

elog_set_colors() {
    if eon "$1"; then
        elog_enable_colors
    else
        elog_disable_colors
    fi
}

# print command in human readable form with option to paste in terminal and run
ecmd() {
    local cmd
    local arg
    local line_count

    for arg in "$@"; do
        line_count="$(echo "$arg" | wc -l)"
        if [ "$line_count" -gt 1 ] || echo "$arg" | grep -q '["`$\\[:space:]]'; then
            cmd="$cmd \"$(echo "$arg" | sed -e 's/\(["`$\\]\)/\\\1/g')\""
        else
            cmd="$cmd $arg"
        fi
    done

    echo "${cmd:1}"
}

# quietly execute the process, ignore output and all errors
eqexec() {
    "$@" > /dev/null 2>&1 || true
}

# execute the process, do enhanced output if process has failed
# if -p is passed then also pass process output on success
eexec() {
    # global ELOG_INDENT
    # global ELOG_COLOR_QUOTE
    # global ELOG_COLOR_RESET

    local passthrough=0

    if [ "$1" = "-p" ]; then
        passthrough=1
        shift
    fi

    local output_file
    local error_code=0

    output_file="$(mktemp)"

    if "$@" > "$output_file" 2>&1; then
        if [ "$passthrough" -eq 1 ]; then
            cat "$output_file"
        fi
    else
        error_code="$?"
        eerror "Process has failed with error code $error_code: $(ecmd "$@")"
        cat "$output_file" \
            | sed -e 's/^/'"$ELOG_INDENT   $ELOG_COLOR_QUOTE>$ELOG_COLOR_RESET "'/' \
            >&2
    fi

    rm "$output_file"

    return $error_code
}
