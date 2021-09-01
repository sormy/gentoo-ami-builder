#!/bin/bash

# global SCRIPT_DIR

# global APP_PHASE2_SCRIPT
# global APP_PHASE3_SCRIPT
# global APP_PHASE4_SCRIPT
# global APP_PHASE5_SCRIPT

# global COLOR
# global COLOR_GREEN
# global COLOR_RED
# global COLOR_YELLOW
# global COLOR_RESET
# global CURL_OPTS
# global EMERGE_OPTS
# global GENKERNEL_OPTS
# global GENTOO_MIRROR
# global GENTOO_GPG_KEYS
# global GENTOO_ARCH
# global GENTOO_STAGE3
# global GETNOO_PROFILE
# global GENTOO_UPDATE_WORLD

bundle_var_list() {
    local var_list="$*"
    local var
    for var in $var_list; do
        echo "$var=\"${!var}\""
    done
}

bundle_func_list() {
    local func_list="$*"
    local func
    for func in $func_list; do
        type "$func" | tail -n +2
    done
}

bundle_phase() {
    local template="$1"
    local elib_file="$2"
    local phase_file="$3"

    # inject ELIB below line with %ELIB% macro
    # remove first line if it looks like shebang (should be last)
    cat "$template" | sed -e "/%ELIB%/r $elib_file" -e '1!b' -e '/^#!/d' > "$phase_file"
}

bundle_lib_file() {
    local file="$1"

    cat > "$file" << END
$(
    bundle_var_list \
        COLOR \
        COLOR_GREEN \
        COLOR_RED \
        COLOR_YELLOW \
        COLOR_RESET \
        CURL_OPTS \
        EMERGE_OPTS \
        GENKERNEL_OPTS \
        GENTOO_MIRROR \
        GENTOO_GPG_KEYS \
        GENTOO_ARCH \
        GENTOO_STAGE3 \
        GENTOO_PROFILE \
        GENTOO_UPDATE_WORLD \
)
$(
    bundle_func_list \
        eon \
        eoff \
        einfo \
        eerror \
        eecho \
        eindent \
        eoutdent \
        edie \
        elog_enable_colors \
        elog_disable_colors \
        elog_set_colors \
        ecmd \
        eexec \
        eqexec \
        find_device \
        append_disk_part \
        find_disk1 \
        find_disk2 \
        download_distfile_safe \
)
elog_set_colors "\$COLOR"
eindent
set -e
#set -x
END
}

bundle_phase_files() {
    local elib_file="$(mktemp)"

    bundle_lib_file "$elib_file"

    APP_PHASE2_SCRIPT=$(mktemp)
    bundle_phase "$SCRIPT_DIR/lib/phase2-prepare-root.sh" "$elib_file" "$APP_PHASE2_SCRIPT"

    APP_PHASE1_X32_SCRIPT=$(mktemp)
    bundle_phase "$SCRIPT_DIR/lib/phase1-prepare-x32.sh" "$elib_file" "$APP_PHASE1_X32_SCRIPT"

    APP_PHASE3_SCRIPT=$(mktemp)
    bundle_phase "$SCRIPT_DIR/lib/phase3-build-root.sh" "$elib_file" "$APP_PHASE3_SCRIPT"

    APP_PHASE4_SCRIPT=$(mktemp)
    bundle_phase "$SCRIPT_DIR/lib/phase4-switch-root.sh" "$elib_file" "$APP_PHASE4_SCRIPT"

    APP_PHASE5_SCRIPT=$(mktemp)
    bundle_phase "$SCRIPT_DIR/lib/phase5-migrate-root.sh" "$elib_file" "$APP_PHASE5_SCRIPT"

    rm "$elib_file"
}
