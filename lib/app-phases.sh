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
# global GENTOO_PROFILE
# global GENTOO_ARCH
# global GENTOO_IMAGE_NAME_PREFIX
# global PAUSE_BEFORE_REBOOT
# global TERMINATE_ON_FAILURE
# global COLOR
# global SSH_OPTS

show_help() {
cat << END
$APP_NAME: $APP_DESCRIPTION v$APP_VERSION
Usage:
    $(basename "$0") [options]
Options:
    --instance-type <value>         (default is "$EC2_INSTANCE_TYPE")
    --amazon-image-id <value>       (default is "$EC2_AMAZON_IMAGE_ID")
    --security-group <value>        (default is "$EC2_SECURITY_GROUP")
    --key-pair <value>
    --gentoo-profile <value>        (default is "$GENTOO_PROFILE")
    --gentoo-image-name <value>     (default is "$GENTOO_IMAGE_NAME_PREFIX")
    --resume-instance-id <value>
    --skip-phases <value>
    --pause-before-reboot <bool>    (default is "$PAUSE_BEFORE_REBOOT")
    --terminate-on-failure <bool>   (default is "$TERMINATE_ON_FAILURE")
    --color <bool>                  (default is "$COLOR")
    --version
    --help
END
}

show_version() {
    echo "$APP_VERSION"
}

show_intro() {
    einfo "$APP_DESCRIPTION v$APP_VERSION"

    einfo "The following parameters will be used:"

    eindent

    einfo "Instance Type: $EC2_INSTANCE_TYPE"
    einfo "Amazon Image ID: $EC2_AMAZON_IMAGE_ID"
    einfo "Security Group: $EC2_SECURITY_GROUP"
    einfo "Key Pair: $EC2_KEY_PAIR"

    einfo "Gentoo Profile: $GENTOO_PROFILE ($GENTOO_ARCH)"
    einfo "Gentoo Image Name: $GENTOO_IMAGE_NAME_PREFIX"

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

    local image_id="$1"
    local amazon_user="$2"

    local virt_type
    local snapshot_id
    local instance_id
    local public_ip

    einfo "PHASE 1: Prepare Instance"

    eindent

    einfo "Verifying virtualization type..."
    virt_type=$(get_image_virtualization_type "$image_id")
    if [ "$virt_type" != "hvm" ]; then
        edie "Provided AMI image has invalid virtualization type: $virt_type"
    fi

    einfo "Detecting snapshot ID..."
    snapshot_id=$(get_image_root_volume_snapshot_id "$image_id")
    einfo "Default image's root volume snapshot ID is $snapshot_id"

    einfo "Running instance..."
    instance_id=$(run_instance "$image_id" "$snapshot_id")
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

show_phase2_prepare_root() {
    # global SSH_OPTS

    local amazon_user="$1"
    local public_ip="$2"
    local phase_script="$3"

    einfo "PHASE 2: Prepare Root"

    eindent

    ssh $SSH_OPTS "$amazon_user@$public_ip" \
        "sudo bash -s" < "$phase_script" \
        || edie "Phase bootstrap has failed"

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

    if is_on "$PAUSE_BEFORE_REBOOT"; then
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

    if is_on "$PAUSE_BEFORE_REBOOT"; then
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
