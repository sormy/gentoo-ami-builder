#!/bin/bash

COLOR_GREEN=$'\033[32m'
COLOR_RED=$'\033[91m'
COLOR_YELLOW=$'\033[93m'
COLOR_RESET=$'\033[00m'

ELOG_GREEN_COLOR=""
ELOG_RED_COLOR=""
ELOG_RESET_COLOR=""
ELOG_YELLOW_COLOR=""

ELOG_INDENT=""

is_on() {
    echo "$1" | grep -q -i '^\(1\|yes\|true\|on\)$'
}

is_off() {
    ! is_on "$1"
}

einfo() {
    # global ELOG_INDENT
    # global ELOG_GREEN_COLOR
    # global ELOG_RESET_COLOR
    echo "$ELOG_GREEN_COLOR *$ELOG_RESET_COLOR$ELOG_INDENT" "$@"
}

eerror() {
    # global ELOG_INDENT
    # global ELOG_RED_COLOR
    # global ELOG_RESET_COLOR
    echo "$ELOG_RED_COLOR *$ELOG_RESET_COLOR$ELOG_INDENT" "$@" >&2
}

eecho() {
    # global ELOG_INDENT
    echo "$ELOG_INDENT  " "$@"
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
    ELOG_INDENT="${ELOG_INDENT::${#ELOG_INDENT}-2}"
}

edie() {
    eerror "$@"
    exit 1
}

elog_enable_colors() {
    ELOG_GREEN_COLOR="$COLOR_GREEN"
    ELOG_RED_COLOR="$COLOR_RED"
    ELOG_RESET_COLOR="$COLOR_RESET"
    ELOG_YELLOW_COLOR="$COLOR_YELLOW"
}

elog_disable_colors() {
    ELOG_GREEN_COLOR=""
    ELOG_RED_COLOR=""
    ELOG_RESET_COLOR=""
    ELOG_YELLOW_COLOR=""
}

elog_set_colors() {
    is_on "$1" && elog_enable_colors || elog_disable_colors
}

# quietly execute the process, ignore output and all errors
qexec() {
    "$@" > /dev/null 2>&1 || true
}

# execute the process, do enhanced output if process has failed
# if -p is passed then also pass process output on success
eexec() {
    # global ELOG_INDENT
    # global ELOG_YELLOW_COLOR
    # global ELOG_RESET_COLOR

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

        local cmd
        local arg
        for arg in "$@"; do cmd="$cmd \"$arg\""; done
        cmd="${cmd:1}"

        eerror "Process has failed with error code $error_code: $cmd"
        cat "$output_file" \
            | sed -e 's/^/'"$ELOG_INDENT   $ELOG_YELLOW_COLOR>$ELOG_RESET_COLOR "'/' \
            >&2
    fi

    rm "$output_file"

    return $error_code
}
