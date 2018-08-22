#!/bin/bash

OPT_CONFIG=""
OPT_OPTIONS=""
OPT_CMD="run"

# called on parse error
opt_error() {
    echo "ERROR:" "$@" >&2
    exit 1
}

# check option value
opt_check() {
    local name="$1"
    local value="$2"

    [ -z "$value" ] && opt_error "Missing value for \"$name\"" || true
}

# save option
opt_save() {
    # global OPT_OPTIONS

    local name="$1"
    local value="$2"

    OPT_OPTIONS="$OPT_OPTIONS"$'\n'"$name=$value"
}

# get command: help | version | run
opt_cmd() {
    echo "$OPT_CMD"
}

# get option value by name
opt_get() {
    # global OPT_OPTIONS

    local name="$1"

    echo "$OPT_OPTIONS" | grep '^'$name'=' | sed -e 's/^.*=//'
}

# print all found options
opt_print_all() {
    # global OPT_OPTIONS

    echo "$OPT_OPTIONS"
}

# set opt configuration
opt_config() {
    # global OPT_CONFIG

    OPT_CONFIG="$1"
}

# parse command line using previosly set configuration
opt_parse() {
    # global OPT_CMD

    while [ "$#" != 0 ]; do
        local arg="$1"

        if [ -z "$arg" ]; then
            opt_error "Unexpected argument \"$1\". Use --help."
        elif [ "$arg" = "--help" ]; then
            OPT_CMD="help"
            return
        elif [ "$arg" = "--version" ]; then
            OPT_CMD="version"
            return
        elif echo " $OPT_CONFIG " | grep -q "[[:blank:]]${arg}[[:blank:]]"; then
            shift
            opt_check "$arg" "$1"
            opt_save "$arg" "$1"
            shift
        else
            opt_error "Unexpected argument \"$1\". Use --help."
        fi
    done
}
