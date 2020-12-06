#!/bin/bash

# global APP_NAME
# global APP_VERSION
# global APP_DESCRIPTION
# global APP_START_TS
# global EC2_INSTANCE_ID
# global EC2_PUBLIC_IP
# global EC2_INSTANCE_TYPE
# global EC2_AMAZON_IMAGE_ID
# global EC2_SECURITY_GROUP
# global GENTOO_STAGE3
# global GENTOO_ARCH
# global GENTOO_IMAGE_NAME_PREFIX
# global PAUSE_BEFORE_REBOOT
# global TERMINATE_ON_FAILURE
# global COLOR
# global SSH_OPTS
# global SCRIPT_DIR

show_help() {
    GENTOO_STAGE3_LIST="$(
        curl -s http://distfiles.gentoo.org/releases/{x86,amd64,arm64}/autobuilds/ \
            | grep -e '"latest-stage3-\S*\.txt"' -o \
            | sed -e 's/"//g' -e 's/^latest-stage3-//' -e 's/\.txt$//' \
            | sort | uniq \
    )"

    GENTOO_PROFILE_LIST="$(
        curl -s https://raw.githubusercontent.com/gentoo/gentoo/master/profiles/profiles.desc \
            | grep '^\(x86\|amd64\|arm64\)\s' | cut -f 3 | sort | uniq \
    )"

cat << END
$APP_NAME: $APP_DESCRIPTION v$APP_VERSION

Usage:
    $(basename "$0") [options]

Options:
    --region <value>                (default is "us-east-1")
        Application tries to guess region by AWS_DEFAULT_REGION environment variable
        with fallback to us-east-1 if AWS_DEFAULT_REGION is not defined.
        List of available regions can be located here:
        https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html

    --instance-type <value>         (default is "$EC2_INSTANCE_TYPE_AMD64" for amd64/x86)
                                    (default is "$EC2_INSTANCE_TYPE_ARM64" for arm64)
        Use specific instance type to bootstrap Gentoo AMI image.
        Instance types: https://aws.amazon.com/ec2/instance-types/
        Pricing: https://aws.amazon.com/ec2/pricing/on-demand/

    --amazon-image-id <value>       (default is "$EC2_AMAZON_IMAGE_ID")
        Use this Amazon Linux image ID to bootstrap Gentoo.
        Automatically detected if not defined.

    --security-group <value>        (default is "$EC2_SECURITY_GROUP")
        Use this security group to bootstrap through SSH (22 port should be open).

    --key-pair <value>
        Use this key pair for SSH access (keys should be available locally).

    --spot-instance <bool>          (default is "$EC2_SPOT_INSTANCE")
        Disable to use on-demand instances instead of spot instances.

    --gentoo-stage3 <value>         (default is "$GENTOO_STAGE3")
        Bootstrap using this stage3:
$(echo "$GENTOO_STAGE3_LIST" | sed 's/^/          * /')

    --gentoo-profile <value>        (default is "$GENTOO_PROFILE")
        If set then switch to this profile during installation:
$(echo "$GENTOO_PROFILE_LIST" | sed 's/^/          * /')

    --gentoo-mirror <value>         (default is "$GENTOO_MIRROR")
        Set to use specific gentoo mirror instead of default one.

    --gentoo-image-name <value>     (default is "$GENTOO_IMAGE_NAME_PREFIX")
        Target Gentoo AMI image name prefix.

    --user-phase <value>
        Script to run after building the base system but before preparing the AMI.

    --resume-instance-id <value>
        (DEBUG) Use already spawned instance for bootstrap.

    --skip-phases <value>
        (DEBUG) List of phase digits to skip (no spaces, commas etc).

    --keep-bootstrap-disk <bool>    (default is "$KEEP_BOOTSTRAP_DISK")
        (DEBUG) Keep bootstrap disk after instance has been terminated.

    --pause-before-reboot <bool>    (default is "$PAUSE_BEFORE_REBOOT")
        (DEBUG) Pause process before reboot.

    --terminate-on-failure <bool>   (default is "$TERMINATE_ON_FAILURE")
        (DEBUG) Could be used to disable instance termination on failure.

    --color <bool>                  (default is "$COLOR")
        Enable or disable colors in output.

    --version
        Show version.

    --help
        Show this screen.
END
}

show_version() {
    echo "$APP_VERSION"
}

show_intro() {
    einfo "$APP_DESCRIPTION v$APP_VERSION"

    einfo "The following parameters will be used:"

    eindent

    einfo "AWS Region: $AWS_REGION"
    einfo "Instance Type: $EC2_INSTANCE_TYPE (spot: $EC2_SPOT_INSTANCE)"
    einfo "Amazon Linux AMI: ${EC2_AMAZON_IMAGE_ID:-auto}"
    einfo "Security Group: $EC2_SECURITY_GROUP"
    einfo "Key Pair: $EC2_KEY_PAIR"

    einfo "Gentoo Stage3: $GENTOO_STAGE3 (ARCH: $GENTOO_ARCH)"
    if [ -n "$GENTOO_PROFILE" ]; then
        einfo "Gentoo Profile: $GENTOO_PROFILE"
    fi
    einfo "Gentoo AMI Name: $GENTOO_IMAGE_NAME_PREFIX"

    eoutdent
}

show_header() {
    # global APP_START_TS

    APP_START_TS=$(date +%s)
    einfo "Started at $(date)"
}

show_footer() {
    einfo "Done at $(date)"

    local ts=$(date +%s)
    local duration_mins=$(expr \( $ts - $APP_START_TS \) / 60)
    einfo "Process took $duration_mins minutes"
}

show_phase1_prepare_instance() {
    # global EC2_INSTANCE_ID
    # global EC2_PUBLIC_IP
    # global EC2_SPOT_INSTANCE

    local image_id="$1"
    local image_arch="$2"
    local amazon_user="$3"

    local actual_image_arch
    local actual_virt_type
    local snapshot_id
    local instance_id
    local public_ip

    einfo "PHASE 1: Prepare Instance"

    eindent

    if [ -z "$image_id" ]; then
        einfo "Detecting last Amazon Linux 2 AMI..."
        image_id=$(get_last_amzn2_image "$image_arch")
        if [ "$image_id" = "None" ] || [ -z "$image_id" ]; then
            edie "Unable to find Amazon Linux 2 AMI"
        else
            einfo "Autodetected image ID is $image_id"
        fi
    else
        einfo "Verifying image architecture..."
        actual_image_arch=$(get_image_architecture "$image_id")
        if [ "$actual_image_arch" != "$image_arch" ]; then
            edie "Provided AMI image has invalid architecture: $actual_image_arch (exptected $image_arch)"
        fi

        einfo "Verifying image virtualization type..."
        actual_virt_type=$(get_image_virtualization_type "$image_id")
        if [ "$actual_virt_type" != "hvm" ]; then
            edie "Provided AMI image has invalid virtualization type: $actual_virt_type (expected hvm)"
        fi
    fi

    einfo "Detecting snapshot ID..."
    snapshot_id=$(get_image_root_volume_snapshot_id "$image_id")
    einfo "Default image's root volume snapshot ID is $snapshot_id"

    if eon "$EC2_SPOT_INSTANCE"; then
        einfo "Requesting spot instance..."
        spot_request_id=$(run_spot_instance "$image_id" "$snapshot_id")

        sleep 5 # spot request status retrieval could not be immediately available

        wait_until_spot_request_fulfilled "$spot_request_id" 30 \
            || edie "Unexpected instance state."

        instance_id=$(get_spot_request_instance_id $spot_request_id)
    else
        einfo "Running instance..."
        instance_id=$(run_instance "$image_id" "$snapshot_id")
    fi

    einfo "Started instance ID is $instance_id"

    sleep 5 # instance status retrieval could be not immediately available

    wait_until_instance_will_be_up "$instance_id" \
        || edie "Unexpected instance state."

    einfo "Detecting public IP address..."
    public_ip=$(get_instance_public_ip "$instance_id")
    einfo "Public IP address is $public_ip"

    wait_until_ssh_will_be_up "$amazon_user" "$public_ip" \
        || edie "Unable to establish SSH connection."

    eoutdent

    EC2_INSTANCE_ID="$instance_id"
    EC2_PUBLIC_IP="$public_ip"
}

show_phase1_use_instance() {
    # global EC2_INSTANCE_ID
    # global EC2_PUBLIC_IP

    einfo "PHASE 1: Prepare Instance (SKIPPED)"

    eindent

    if [ -n "$EC2_INSTANCE_ID" ]; then
        einfo "Using existing instance $EC2_INSTANCE_ID"
    else
        edie "Use --resume-instance-id to run with skipped phase 1."
    fi

    einfo "Detecting public IP address..."
    EC2_PUBLIC_IP=$(get_instance_public_ip "$EC2_INSTANCE_ID")
    einfo "Public IP address is $EC2_PUBLIC_IP"

    eoutdent
}

show_phase1_prepare_x32() {
    # global SSH_OPTS
    # global USER_PHASE

    local instance_id="$1"
    local amazon_user="$2"
    local public_ip="$3"
    local phase_script="$4"

    einfo "PHASE 1x: Prepare x32"

    eindent

    # amazon user has no superuser privileges so we have to use sudo
    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo bash -s" < "$phase_script" \
        || edie "Phase bootstrap has failed"

    einfo "Rebooting..."

    if eon "$PAUSE_BEFORE_REBOOT"; then
        signal
        press_any_key_to_continue
    fi

    # reboot will terminate ssh session so this command will fail on success
    # amazon user has no superuser privileges so we have to use sudo
    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo reboot" || true

    sleep 30

    wait_until_instance_will_be_up "$instance_id" \
        || edie "Unexpected instance state."

    wait_until_ssh_will_be_up "$amazon_user" "$public_ip" \
        || edie "Unable to establish SSH connection."

    eoutdent
}

show_phase2_prepare_root() {
    # global SSH_OPTS
    # global USER_PHASE

    local amazon_user="$1"
    local public_ip="$2"
    local phase_script="$3"

    einfo "PHASE 2: Prepare Root"

    eindent

    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo bash -s" < "$phase_script" \
        || edie "Phase bootstrap has failed"

    einfo "Sideloading ec2-init..."

    mkdir -p "$SCRIPT_DIR/cache"

    for file in ec2-init.openrc ec2-init.service ec2-init.script; do
        if [ ! -f "$SCRIPT_DIR/cache/$file" ]; then
            curl $CURL_OPTS "https://raw.githubusercontent.com/sormy/ec2-init/master/$file" \
                -o "$SCRIPT_DIR/cache/$file"
        fi
    done

    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo bash -c 'cat > /mnt/gentoo/ec2-init.openrc'" \
        < "$SCRIPT_DIR/cache/ec2-init.openrc"

    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo bash -c 'cat > /mnt/gentoo/ec2-init.service'" \
        < "$SCRIPT_DIR/cache/ec2-init.service"

    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo bash -c 'cat > /mnt/gentoo/ec2-init.script'" \
        < "$SCRIPT_DIR/cache/ec2-init.script"

    if [ -n "$USER_PHASE" ]; then
        einfo "Sideloading user phase..."

        ssh $SSH_OPTS "$amazon_user@$public_ip" \
            "sudo bash -c 'cat > /mnt/gentoo/user-phase'" \
            < "$USER_PHASE"
    fi

    eoutdent
}

show_phase3_build_root() {
    # global SSH_OPTS

    local amazon_user="$1"
    local public_ip="$2"
    local phase_script="$3"

    einfo "PHASE 3: Build Root"

    eindent

    # amazon user has no superuser privileges so we have to use sudo
    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo chroot /mnt/gentoo /bin/bash -s" < "$phase_script" \
        || edie "Phase bootstrap has failed"

    eoutdent
}

show_phase4_switch_root() {
    # global SSH_OPTS

    local instance_id="$1"
    local amazon_user="$2"
    local gentoo_user="$3"
    local public_ip="$4"
    local phase_script="$5"

    einfo "PHASE 4: Switch Root"

    eindent

    # amazon user has no superuser privileges so we have to use sudo
    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo bash -s" < "$phase_script" \
        || edie "Phase bootstrap has failed"

    einfo "Rebooting..."

    if eon "$PAUSE_BEFORE_REBOOT"; then
        signal
        press_any_key_to_continue
    fi

    # reboot will terminate ssh session so this command will fail on success
    # amazon user has no superuser privileges so we have to use sudo
    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo reboot" || true

    sleep 30

    wait_until_instance_will_be_up "$instance_id" \
        || edie "Unexpected instance state."

    wait_until_ssh_will_be_up "$gentoo_user" "$public_ip" \
        || edie "Unable to establish SSH connection."

    eoutdent
}

show_phase5_migrate_boot() {
    # global SSH_OPTS

    local instance_id="$1"
    local gentoo_user="$2"
    local public_ip="$3"
    local phase_script="$4"

    einfo "PHASE 5: Migrate Root"

    eindent

    ssh $SSH_OPTS "$gentoo_user@$public_ip" \
        "bash -s" < "$phase_script" \
        || edie "Phase bootstrap has failed"

    einfo "Rebooting..."

    if eon "$PAUSE_BEFORE_REBOOT"; then
        signal
        press_any_key_to_continue
    fi

    # reboot will terminate ssh session so this command will fail on success
    ssh $SSH_OPTS "$gentoo_user@$public_ip" \
        "reboot" || true

    sleep 30

    wait_until_instance_will_be_up "$instance_id" \
        || edie "Unexpected instance state."

    wait_until_ssh_will_be_up "$gentoo_user" "$public_ip" \
        || edie "Unable to establish SSH connection."

    eoutdent
}

show_phase6_build_ami() {
    local instance_id="$1"
    local name_prefix="$2"

    local image_id
    local image_name
    local account_id

    einfo "PHASE 6: Build AMI"

    eindent

    image_name="$name_prefix $(date +"%Y-%m-%d %s")"

    einfo "Creating AMI image \"$image_name\"..."
    image_id="$(create_image "$instance_id" "$image_name")"
    einfo "Created AMI image ID is $image_id"

    einfo "Verifying AMI image state..."
    verify_image_state "$image_id"

    wait_until_image_will_be_available "$image_id" \
        || edie "Unexpected AMI image state."

    einfo "Retrieving AWS account ID..."
    account_id="$(get_account_id)"
    einfo "Retrieved AWS account ID is $account_id"

    remove_outdated_images "$account_id" "$name_prefix" "$image_id"

    einfo "Terminating instance..."
    terminate_instance "$instance_id"

    eoutdent
}
