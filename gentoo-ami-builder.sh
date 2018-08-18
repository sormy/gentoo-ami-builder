#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

# shellcheck source=lib/app-lib.sh
source "$SCRIPT_DIR/lib/app-lib.sh"
# shellcheck source=lib/app-opts.sh
source "$SCRIPT_DIR/lib/app-opts.sh"
# shellcheck source=lib/app-phases.sh
source "$SCRIPT_DIR/lib/app-phases.sh"
# shellcheck source=lib/app-trap.sh
source "$SCRIPT_DIR/lib/app-trap.sh"
# shellcheck source=lib/elib-bundle.sh
source "$SCRIPT_DIR/lib/elib-bundle.sh"
# shellcheck source=lib/elib-core.sh
source "$SCRIPT_DIR/lib/elib-core.sh"
# shellcheck source=lib/glib-disk.sh
source "$SCRIPT_DIR/lib/glib-disk.sh"
# shellcheck source=lib/glib-ena.sh
source "$SCRIPT_DIR/lib/glib-ena.sh"

APP_NAME="gentoo-ami-builder"
APP_DESCRIPTION="Gentoo AMI Builder"
APP_VERSION="1.0.0"

# Security group with incoming connection available on SSH port (22).
EC2_SECURITY_GROUP="default"

# SSH key pair that will be used to connect to build instance.
# The private key should be available locally to log into host.
EC2_KEY_PAIR=""

# Instance type that will be used as compile host.
# Recommended is compute-optimized instance type.
EC2_INSTANCE_TYPE="c5.2xlarge"

# Default volume size in GB.
EC2_VOLUME_SIZE="20"

# Default volume type.
EC2_VOLUME_TYPE="gp2"

# Set to the latest Amazon Linux AMI. You could find it in AWS console.
EC2_AMAZON_IMAGE_ID="ami-b70554c8" # Amazon Linux 2 AMI as of 2018-08-12

# Default user name to log into Amazon Linux.
AMAZON_USER="ec2-user"

# Default user name to log into Gentoo Linux.
GENTOO_USER="root"

# Highly recommended options for SSH during bootstrap.
SSH_OPTS="-o ConnectTimeout=5
          -o KbdInteractiveAuthentication=no
          -o ChallengeResponseAuthentication=no
          -o UserKnownHostsFile=/dev/null
          -o StrictHostKeyChecking=no
          -o LogLevel=error"

# Recommended default options for wget.
WGET_OPTS="--quiet"

# Recommended default options for emerge.
EMERGE_OPTS="--quiet"

# Recommended default options for genkernel.
GENKERNEL_OPTS="--no-color"

# By default it also includes EFI, but it is useless for AWS instances.
GRUB_PLATFORMS="pc"

# Gentoo profile, see README for more details.
GENTOO_PROFILE="amd64"

# Available Gentoo architectures in EC2 are amd64 and x86.
GENTOO_ARCH="amd64"

# Primary Gentoo mirror to look for Gentoo stage tarballs and portage snapshots.
GENTOO_DISTFILES_URL="http://distfiles.gentoo.org"

# Target AMI image prefix.
GENTOO_IMAGE_NAME_PREFIX="Gentoo Linux"

# Enable/disable colors in output.
COLOR="yes"

# Required if you are would like to use already running instance.
EC2_INSTANCE_ID=""

# Used for debugging purposes if something goes wrong.
SKIP_PHASES=""

# Wait for keypress each time before rebooting the instance (could be useful for debug purposes).
PAUSE_BEFORE_REBOOT="no"

# Terminate instance on failure (keeping it up could be useful for debug purposes).
TERMINATE_ON_FAILURE="yes"

# Application phase script filenames.
APP_PHASE2_SCRIPT=""
APP_PHASE3_SCRIPT=""
APP_PHASE4_SCRIPT=""
APP_PHASE5_SCRIPT=""

# Store instance public ip to be able to log into over SSH.
EC2_PUBLIC_IP=""

# Stop on any error required to properly handle errors.
set -e

# Parse arguments and make them available for get_arg() function.
parse_args "$@"

# Show help screen immeditely if selected.
if [ "$APP_COMMAND" = "help" ]; then
    show_help
    exit
fi

# Show version screen immeditely if selected.
if [ "$APP_COMMAND" = "version" ]; then
    show_version
    exit
fi

# Override default values if they are passed from command line.
ARG="$(get_arg --instance-type)";       [ -z "$ARG" ] || EC2_INSTANCE_TYPE="$ARG"
ARG="$(get_arg --amazon-image-id)";     [ -z "$ARG" ] || EC2_AMAZON_IMAGE_ID="$ARG"
ARG="$(get_arg --security-group)";      [ -z "$ARG" ] || EC2_SECURITY_GROUP="$ARG"
ARG="$(get_arg --key-pair)";            [ -z "$ARG" ] || EC2_KEY_PAIR="$ARG"
ARG="$(get_arg --gentoo-profile)";      [ -z "$ARG" ] || GENTOO_PROFILE="$ARG"
ARG="$(get_arg --gentoo-image-name)";   [ -z "$ARG" ] || GENTOO_IMAGE_NAME_PREFIX="$ARG"
ARG="$(get_arg --resume-instance-id)";  [ -z "$ARG" ] || EC2_INSTANCE_ID="$ARG"
ARG="$(get_arg --skip-phases)";         [ -z "$ARG" ] || SKIP_PHASES="$ARG"
ARG="$(get_arg --pause-before-reboot)"; [ -z "$ARG" ] || PAUSE_BEFORE_REBOOT="$ARG"
ARG="$(get_arg --terminate-on-failure)";[ -z "$ARG" ] || TERMINATE_ON_FAILURE="$ARG"
ARG="$(get_arg --color)";               [ -z "$ARG" ] || COLOR="$ARG"

# If resume is enabled then we should skip first phase.
if [ -n "$EC2_INSTANCE_ID" ]; then
    SKIP_PHASES="1${SKIP_PHASES}"
fi

# Auto detect gentooo architecture based on provided gentoo profile.
GENTOO_ARCH=$(echo "$GENTOO_PROFILE" | grep -q '^\(amd64\|x32\)' && echo "amd64" || echo "x86")

# Add profile name into default image name prefix.
GENTOO_IMAGE_NAME_PREFIX="$GENTOO_IMAGE_NAME_PREFIX ($GENTOO_PROFILE)"

# Die on configuration that are well know to not work with current version of the script.
[ "$GENTOO_ARCH" = "x86" ] && edie "Gentoo x86 Architecture is not supported yet."

# Install error handler that will terminate instance and cleanup temporary files.
trap app_exit_trap EXIT

# Set colors enabled/disabled based on configuration.
elog_set_colors "$COLOR"

# Create temporary files that will be used for bootstrapping.
bundle_phase_files

# Show smalli intro screen with basic information about selected parameters.
show_intro

# Show header with timestamp.
show_header

# Run phase 1 if enabled: Prepare Instance
if ! is_phase_skipped 1; then
    # sets EC2_INSTANCE_ID and EC2_PUBLIC_IP
    show_phase1_prepare_instance "$EC2_AMAZON_IMAGE_ID" "$AMAZON_USER"
else
    # try to use existing instance, should be passed from command line
    show_phase1_use_instance
fi

# Run phase 2 if enabled: Prepare Root
if ! is_phase_skipped 2; then
    show_phase2_prepare_root "$AMAZON_USER" "$EC2_PUBLIC_IP" "$APP_PHASE2_SCRIPT"
fi

# Run phase 3 if enabled: Build Root
if ! is_phase_skipped 3; then
    show_phase3_build_root "$AMAZON_USER" "$EC2_PUBLIC_IP" "$APP_PHASE3_SCRIPT"
fi

# Run phase 4 if enabled: Switch Root
if ! is_phase_skipped 4; then
    show_phase4_switch_root "$EC2_INSTANCE_ID" "$AMAZON_USER" "$GENTOO_USER" \
        "$EC2_PUBLIC_IP" "$APP_PHASE4_SCRIPT"
fi

# Run phase 5 if enabled: Migrate Root
if ! is_phase_skipped 5; then
    show_phase5_migrate_boot "$EC2_INSTANCE_ID" "$GENTOO_USER" "$EC2_PUBLIC_IP" \
        "$APP_PHASE5_SCRIPT"
fi

# Run phase 6 if enabled: Build AMI
if ! is_phase_skipped 6; then
    show_phase6_build_ami "$EC2_INSTANCE_ID" "$GENTOO_IMAGE_NAME_PREFIX"
fi

# Show footer with timestamp and duration of the process.
show_footer
