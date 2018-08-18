#!/bin/bash

# global APP_PHASE2_SCRIPT
# global APP_PHASE3_SCRIPT
# global APP_PHASE4_SCRIPT
# global APP_PHASE5_SCRIPT
# global TERMINATE_ON_FAILURE
# global EC2_INSTANCE_ID

app_exit_trap() {
    [ -e "$APP_PHASE2_SCRIPT" ] && rm "$APP_PHASE2_SCRIPT" || true
    [ -e "$APP_PHASE3_SCRIPT" ] && rm "$APP_PHASE3_SCRIPT" || true
    [ -e "$APP_PHASE4_SCRIPT" ] && rm "$APP_PHASE4_SCRIPT" || true
    [ -e "$APP_PHASE5_SCRIPT" ] && rm "$APP_PHASE5_SCRIPT" || true

    eindent_reset

    if is_on "$TERMINATE_ON_FAILURE" && [ -n "$EC2_INSTANCE_ID" ]; then
        if [ "$(get_instance_state $EC2_INSTANCE_ID)" = "running" ]; then
            einfo "Terminating instance..."
            terminate_instance "$EC2_INSTANCE_ID"
        fi
    fi
}
