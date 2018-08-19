#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

source "$SCRIPT_DIR/../lib/elib-core.sh"

test_ecmd_no_unnecessary_escaping() {
    actual="$(ecmd "1" "2")"
    assertEquals "1 2" "$actual"
}

test_ecmd_escapes_whitespace() {
    actual="$(ecmd "1" " " "2")"
    assertEquals "1 \" \" 2" "$actual"
}

test_ecmd_escapes_dollar() {
    actual="$(ecmd "1" '$' "2")"
    assertEquals "1 \"\\$\" 2" "$actual"
}

test_ecmd_escapes_slash() {
    actual="$(ecmd "1" "\\" "2")"
    assertEquals "1 \"\\\\\" 2" "$actual"
}

test_ecmd_escapes_apostrophe() {
    actual="$(ecmd "1" "\`" "2")"
    assertEquals "1 \"\\\`\" 2" "$actual"
}

test_ecmd_escapes_double_quotes() {
    actual="$(ecmd "1" "\"" "2")"
    assertEquals "1 \"\\\"\" 2" "$actual"
}

test_ecmd_real_world_example() {
    src=(aws ec2 describe-images
        --owners "1234567890"
        --filters "Name=name,Values=Gentoo Image (amd64) *"
        --query "Images[?ImageId!=\`ami-1234567890\`].ImageId")
    actual="$(ecmd "${src[@]}")"
    expected="aws ec2 describe-images --owners 1234567890"`
        `" --filters \"Name=name,Values=Gentoo Image (amd64) *\""`
        `" --query \"Images[?ImageId!=\\\`ami-1234567890\\\`].ImageId\""
    assertEquals "$expected" "$actual"
}

test_eexec_hides_output_if_no_errors() {
    actual_output="$(eexec echo hello world)"
    actual_error_code="$?"
    assertEquals "error code" "0" "$actual_error_code"
    assertEquals "output" "" "$actual_output"
}

test_eexec_shows_output_if_no_errors_but_in_passthrough_mode() {
    actual_output="$(eexec -p echo hello world)"
    actual_error_code="$?"
    assertEquals "error code" "0" "$actual_error_code"
    assertEquals "output" "hello world" "$actual_output"
}

test_eexec_handles_errors() {
    actual_output="$(eexec mkdir / 2>&1)"
    actual_error_code="$?"
    read -r -d '' expected_output << EOF
 * Process has failed with error code 1: mkdir /
   > mkdir: /: Is a directory
EOF
    assertNotEquals "error code" "0" "$actual_error_code"
    assertEquals "output" " $expected_output" "$actual_output"
}

test_eexec_respects_elog_variables() {
    ELOG_INDENT="  "
    ELOG_RED_COLOR="(red)"
    ELOG_YELLOW_COLOR="(yellow)"
    ELOG_RESET_COLOR="(reset)"
    actual_output="$(eexec mkdir / 2>&1)"
    ELOG_INDENT=""
    ELOG_RED_COLOR=""
    ELOG_YELLOW_COLOR=""
    ELOG_RESET_COLOR=""
    read -r -d '' expected_output << EOF
 (red)*(reset)   Process has failed with error code 1: mkdir /
     (yellow)>(reset) mkdir: /: Is a directory
EOF
    assertEquals "output" " $expected_output" "$actual_output"
}

source ./shunit2
