#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

# shellcheck source=lib/app-lib.sh
source "$SCRIPT_DIR/lib/app-lib.sh"
# shellcheck source=lib/opt.sh
source "$SCRIPT_DIR/lib/opt.sh"
# shellcheck source=lib/app-phases.sh
source "$SCRIPT_DIR/lib/app-phases.sh"
# shellcheck source=lib/app-trap.sh
source "$SCRIPT_DIR/lib/app-trap.sh"
# shellcheck source=lib/bundle.sh
source "$SCRIPT_DIR/lib/bundle.sh"
# shellcheck source=lib/elib.sh
source "$SCRIPT_DIR/lib/elib.sh"
# shellcheck source=lib/disk.sh
source "$SCRIPT_DIR/lib/disk.sh"
# shellcheck source=lib/distfiles.sh
source "$SCRIPT_DIR/lib/distfiles.sh"

APP_NAME="gentoo-ami-builder"
APP_DESCRIPTION="Gentoo AMI Builder"
APP_VERSION="1.1.2"

# AWS region.
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Security group with incoming connection available on SSH port (22).
EC2_SECURITY_GROUP="default"

# SSH key pair that will be used to connect to build instance.
# The private key should be available locally to log into host.
EC2_KEY_PAIR=""

# Instance type that will be used as compile host.
# Recommended is compute-optimized instance type.
EC2_INSTANCE_TYPE=""
EC2_INSTANCE_TYPE_AMD64="c5.2xlarge"
EC2_INSTANCE_TYPE_ARM64="a1.2xlarge"

# Instance architecture: i386, x86_64, arm64.
EC2_ARCH=""

# Default volume size in GB.
EC2_VOLUME_SIZE="20"

# Default volume type.
EC2_VOLUME_TYPE="gp2"

# Set to the latest Amazon Linux AMI for selected architecture and region.
EC2_AMAZON_IMAGE_ID=""

# Default choice of on demand vs spot instance
EC2_SPOT_INSTANCE="true"

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
          -o LogLevel=error
          -o ServerAliveInterval=60
          -o ServerAliveCountMax=3"

# Curl default options.
CURL_OPTS="--silent --fail"

# Recommended default options for emerge.
EMERGE_OPTS="--quiet"

# Recommended default options for genkernel.
GENKERNEL_OPTS="--no-color"

# Gentoo stage3.
GENTOO_STAGE3="amd64"

# Gentoo profile. Blank indicates that stage3 default profile should be used.
GENTOO_PROFILE=""

# Pick the emerge @world update mode: no | rebuild | deep | fast
GENTOO_UPDATE_WORLD="fast"

# Available Gentoo architectures in EC2 are amd64 and x86.
GENTOO_ARCH=""

# Primary Gentoo mirror to look for Gentoo stage tarballs and portage snapshots.
GENTOO_MIRROR="http://distfiles.gentoo.org"

# Current Gentoo GPG public key IDs: https://www.gentoo.org/downloads/signatures/
GENTOO_GPG_KEYS="$(cat "$SCRIPT_DIR/gentoo-gpg-keys.conf" | grep -v '^#')"

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

# Keep disk2 volume after instance has been terminated (for debug purposes).
KEEP_BOOTSTRAP_DISK="no"

# Application phase script filenames.
APP_PHASE1_X32_SCRIPT=""
APP_PHASE2_SCRIPT=""
APP_PHASE3_SCRIPT=""
APP_PHASE4_SCRIPT=""
APP_PHASE5_SCRIPT=""

# Store instance public ip to be able to log into over SSH.
EC2_PUBLIC_IP=""

# Stop on any error required to properly handle errors.
set -e

opt_config "
    --region \
    --instance-type \
    --amazon-image-id \
    --security-group \
    --spot-instance \
    --key-pair \
    --gentoo-stage3 \
    --gentoo-profile \
    --update-world \
    --gentoo-mirror \
    --gentoo-image-name \
    --user-phase \
    --resume-instance-id \
    --skip-phases \
    --pause-before-reboot \
    --terminate-on-failure \
    --keep-bootstrap-disk \
    --color \
"

# Parse arguments and make them available for opt_get() function.
opt_parse "$@"

# Show help screen immeditely if selected.
if [ "$(opt_cmd)" = "help" ]; then
    show_help
    exit
fi

# Show version screen immeditely if selected.
if [ "$(opt_cmd)" = "version" ]; then
    show_version
    exit
fi

# Override default values if they are passed from command line.
OPT="$(opt_get --region)";              [ -z "$OPT" ] || AWS_REGION="$OPT"
OPT="$(opt_get --instance-type)";       [ -z "$OPT" ] || EC2_INSTANCE_TYPE="$OPT"
OPT="$(opt_get --amazon-image-id)";     [ -z "$OPT" ] || EC2_AMAZON_IMAGE_ID="$OPT"
OPT="$(opt_get --spot-instance)";       [ -z "$OPT" ] || EC2_SPOT_INSTANCE="$OPT"
OPT="$(opt_get --security-group)";      [ -z "$OPT" ] || EC2_SECURITY_GROUP="$OPT"
OPT="$(opt_get --key-pair)";            [ -z "$OPT" ] || EC2_KEY_PAIR="$OPT"
OPT="$(opt_get --gentoo-stage3)";       [ -z "$OPT" ] || GENTOO_STAGE3="$OPT"
OPT="$(opt_get --gentoo-profile)";      [ -z "$OPT" ] || GENTOO_PROFILE="$OPT"
OPT="$(opt_get --update-world)";        [ -z "$OPT" ] || GENTOO_UPDATE_WORLD="$OPT"
OPT="$(opt_get --gentoo-mirror)";       [ -z "$OPT" ] || GENTOO_MIRROR="$OPT"
OPT="$(opt_get --gentoo-image-name)";   [ -z "$OPT" ] || GENTOO_IMAGE_NAME_PREFIX="$OPT"
OPT="$(opt_get --user-phase)";          [ -z "$OPT" ] || USER_PHASE="$OPT"
OPT="$(opt_get --resume-instance-id)";  [ -z "$OPT" ] || EC2_INSTANCE_ID="$OPT"
OPT="$(opt_get --skip-phases)";         [ -z "$OPT" ] || SKIP_PHASES="$OPT"
OPT="$(opt_get --pause-before-reboot)"; [ -z "$OPT" ] || PAUSE_BEFORE_REBOOT="$OPT"
OPT="$(opt_get --terminate-on-failure)";[ -z "$OPT" ] || TERMINATE_ON_FAILURE="$OPT"
OPT="$(opt_get --keep-bootstrap-disk)"; [ -z "$OPT" ] || KEEP_BOOTSTRAP_DISK="$OPT"
OPT="$(opt_get --color)";               [ -z "$OPT" ] || COLOR="$OPT"

# If resume is enabled then we should skip first phase.
if [ -n "$EC2_INSTANCE_ID" ]; then
    SKIP_PHASES="1${SKIP_PHASES}"
fi

# Auto detect Gentoo architecture and base AMI based on provided Gentoo profile.
case "$GENTOO_STAGE3" in
    amd64* | x32* )
        GENTOO_ARCH="amd64"
        EC2_INSTANCE_TYPE="${EC2_INSTANCE_TYPE:-$EC2_INSTANCE_TYPE_AMD64}"
        EC2_ARCH="x86_64"
        ;;
    arm64* )
        GENTOO_ARCH="arm64"
        EC2_INSTANCE_TYPE="${EC2_INSTANCE_TYPE:-$EC2_INSTANCE_TYPE_ARM64}"
        EC2_ARCH="arm64"
        ;;
    i486* | i686* )
        GENTOO_ARCH="x86"
        EC2_INSTANCE_TYPE="${EC2_INSTANCE_TYPE:-$EC2_INSTANCE_TYPE_AMD64}"
        EC2_ARCH="i386"
        ;;
    * )
        edie "Unable to detect Gentoo architecture from stage3 name: $GENTOO_STAGE3"
esac

# Add profile name into default image name prefix.
if [ -z "$GENTOO_PROFILE" ]; then
    GENTOO_IMAGE_NAME_PREFIX="$GENTOO_IMAGE_NAME_PREFIX ($GENTOO_STAGE3)"
else
    GENTOO_IMAGE_NAME_PREFIX="$GENTOO_IMAGE_NAME_PREFIX ($GENTOO_STAGE3 - $GENTOO_PROFILE)"
fi

# Sanitize image name to be accepted by AWS as AMI name.
GENTOO_IMAGE_NAME_PREFIX=$(echo "$GENTOO_IMAGE_NAME_PREFIX" | sed 's![^ a-zA-Z0-9()./_-]!-!g')

# Install error handler that will terminate instance and cleanup temporary files.
trap app_exit_trap EXIT

# Set colors enabled/disabled based on configuration.
elog_set_colors "$COLOR"

# Create temporary files that will be used for bootstrapping.
bundle_phase_files

# Show smalli intro screen with basic information about selected parameters.
show_intro

# Die on configuration that is well know to not work with current version of the script.
if [ "$GENTOO_ARCH" = "x86" ]; then
    eerror "Gentoo $GENTOO_ARCH architecture is not supported yet."
    exit 1
fi

# Show header with timestamp.
show_header

# Run phase 1 if enabled: Prepare Instance
if ! is_phase_skipped 1; then
    # sets EC2_INSTANCE_ID and EC2_PUBLIC_IP
    show_phase1_prepare_instance "$EC2_AMAZON_IMAGE_ID" "$EC2_ARCH" "$AMAZON_USER"

    # rebuild kernel for x32 if needed
    if [ "$GENTOO_STAGE3" = "x32" ]; then
        show_phase1_prepare_x32 "$EC2_INSTANCE_ID" "$AMAZON_USER" \
            "$EC2_PUBLIC_IP" "$APP_PHASE1_X32_SCRIPT"
    fi
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
