#!/bin/bash

# global APP_ARGS
# global APP_COMMAND

APP_ARGS=""
APP_COMMAND="run"

error_arg() {
    echo "ERROR:" "$@" >&2
    exit 1
}

check_arg() {
    local name="$1"
    local value="$2"

    [ -z "$value" ] && error_arg "Missing value for \"$name\"" || true
}

save_arg() {
    # global APP_ARGS

    local name="$1"
    local value="$2"

    APP_ARGS="$APP_ARGS"$'\n'"$name=$value"
}

get_arg() {
    # global APP_ARGS

    local name="$1"

    echo "$APP_ARGS" | grep '^'$name'=' | sed -e 's/^.*=//'
}

print_args() {
    # global APP_ARGS

    echo "$APP_ARGS"
}

# returns name of command: "version" | "help" | "run"
parse_args() {
    # global APP_COMMAND

    while [ "$#" != 0 ]; do
        local arg="$1"

        case "$arg" in
            --instance-type \
            | --amazon-image-id \
            | --security-group \
            | --key-pair \
            | --gentoo-profile \
            | --gentoo-image-name \
            | --resume-instance-id \
            | --skip-phases \
            | --pause-before-reboot \
            | --terminate-on-failure \
            | --color )
                shift
                check_arg "$arg" "$1"
                save_arg "$arg" "$1"
                shift
                ;;
            --version )
                APP_COMMAND="version"
                return
                ;;
            --help )
                APP_COMMAND="help"
                return
                ;;
            *)
                error_arg "Unexpected argument \"$1\". Use --help."
        esac
    done
}
