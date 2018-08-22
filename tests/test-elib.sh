#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

source "$SCRIPT_DIR/../lib/elib.sh"

test_eon_true() {
    assertEquals "1" "$(eon "TrUe" && echo 1 || echo 0)"
    assertEquals "1" "$(eon "true" && echo 1 || echo 0)"
    assertEquals "1" "$(eon "on" && echo 1 || echo 0)"
    assertEquals "1" "$(eon "yes" && echo 1 || echo 0)"
    assertEquals "1" "$(eon "1" && echo 1 || echo 0)"
}

test_eon_false() {
    assertEquals "0" "$(eon "FaLsE" && echo 1 || echo 0)"
    assertEquals "0" "$(eon "false" && echo 1 || echo 0)"
    assertEquals "0" "$(eon "off" && echo 1 || echo 0)"
    assertEquals "0" "$(eon "no" && echo 1 || echo 0)"
    assertEquals "0" "$(eon "0" && echo 1 || echo 0)"
    assertEquals "0" "$(eon "garbage" && echo 1 || echo 0)"
}

test_eoff_false() {
    assertEquals "0" "$(eoff "TrUe" && echo 1 || echo 0)"
    assertEquals "0" "$(eoff "true" && echo 1 || echo 0)"
    assertEquals "0" "$(eoff "on" && echo 1 || echo 0)"
    assertEquals "0" "$(eoff "yes" && echo 1 || echo 0)"
    assertEquals "0" "$(eoff "1" && echo 1 || echo 0)"
}

test_eoff_true() {
    assertEquals "1" "$(eoff "FaLsE" && echo 1 || echo 0)"
    assertEquals "1" "$(eoff "false" && echo 1 || echo 0)"
    assertEquals "1" "$(eoff "off" && echo 1 || echo 0)"
    assertEquals "1" "$(eoff "no" && echo 1 || echo 0)"
    assertEquals "1" "$(eoff "0" && echo 1 || echo 0)"
    assertEquals "1" "$(eoff "garbage" && echo 1 || echo 0)"
}

test_einfo_no_colors_no_indent() {
    actual="$(einfo "test" "message")"
    assertEquals " * test message" "$actual"
}

test_einfo_with_colors_and_indent() {
    ELOG_INDENT="  "
    ELOG_COLOR_OK="{green}"
    ELOG_COLOR_RESET="{reset}"
    actual="$(einfo "test" "message")"
    ELOG_INDENT=""
    ELOG_COLOR_OK=""
    ELOG_COLOR_RESET=""
    assertEquals " {green}*{reset}   test message" "$actual"
}

test_eerror_no_colors_no_indent() {
    actual="$(eerror "test" "message" 2>&1)"
    assertEquals " * test message" "$actual"
}

test_eerror_with_colors_and_indent() {
    ELOG_INDENT="  "
    ELOG_COLOR_ERROR="{red}"
    ELOG_COLOR_RESET="{reset}"
    actual="$(eerror "test" "message" 2>&1)"
    ELOG_INDENT=""
    ELOG_COLOR_ERROR=""
    ELOG_COLOR_RESET=""
    assertEquals " {red}*{reset}   test message" "$actual"
}

test_eecho_no_indent() {
    actual="$(eecho "test" "message")"
    assertEquals "   test message" "$actual"
}

test_eecho_with_indent() {
    ELOG_INDENT="  "
    actual="$(eecho "test" "message")"
    ELOG_INDENT=""
    assertEquals "     test message" "$actual"
}

test_eindent_reset() {
    ELOG_INDENT="    "
    eindent_reset
    assertEquals "" "$ELOG_INDENT"
}

test_eindent() {
    assertEquals "" "$ELOG_INDENT"

    eindent
    assertEquals "  " "$ELOG_INDENT"

    eindent
    assertEquals "    " "$ELOG_INDENT"
}

test_outdent() {
    ELOG_INDENT="    "

    eoutdent
    assertEquals "  " "$ELOG_INDENT"

    eoutdent
    assertEquals "" "$ELOG_INDENT"

    eoutdent
    assertEquals "" "$ELOG_INDENT"
}

test_edie() {
    actual_output="$(edie fatal error 2>&1)"
    actual_error_code="$?"
    assertEquals " * fatal error" "$actual_output"
    assertEquals "1" "$actual_error_code"
}

test_elog_enable_colors() {
    assertEquals "" "$ELOG_COLOR_OK"
    assertEquals "" "$ELOG_COLOR_ERROR"
    assertEquals "" "$ELOG_COLOR_RESET"
    assertEquals "" "$ELOG_COLOR_QUOTE"

    elog_enable_colors

    assertEquals "$COLOR_GREEN" "$ELOG_COLOR_OK"
    assertEquals "$COLOR_RED" "$ELOG_COLOR_ERROR"
    assertEquals "$COLOR_RESET" "$ELOG_COLOR_RESET"
    assertEquals "$COLOR_YELLOW" "$ELOG_COLOR_QUOTE"

    ELOG_COLOR_OK=""
    ELOG_COLOR_ERROR=""
    ELOG_COLOR_RESET=""
    ELOG_COLOR_QUOTE=""
}

test_elog_disable_colors() {
    ELOG_COLOR_OK="$COLOR_GREEN"
    ELOG_COLOR_ERROR="$COLOR_RED"
    ELOG_COLOR_RESET="$COLOR_RESET"
    ELOG_COLOR_QUOTE="$COLOR_YELLOW"

    elog_disable_colors

    assertEquals "" "$ELOG_COLOR_OK"
    assertEquals "" "$ELOG_COLOR_ERROR"
    assertEquals "" "$ELOG_COLOR_RESET"
    assertEquals "" "$ELOG_COLOR_QUOTE"
}

test_elog_set_colors() {
    assertEquals "" "$ELOG_COLOR_OK"

    elog_set_colors on

    assertEquals "$COLOR_GREEN" "$ELOG_COLOR_OK"

    elog_set_colors off

    assertEquals "" "$ELOG_COLOR_OK"
}

test_ecmd_no_unnecessary_escaping() {
    actual="$(ecmd "1" "2")"
    assertEquals "1 2" "$actual"
}

test_ecmd_escapes_space() {
    actual="$(ecmd "1" " " "2")"
    assertEquals "1 \" \" 2" "$actual"
}

test_ecmd_escapes_tab() {
    actual="$(ecmd "1" $'1\t2' "2")"
    assertEquals "1 \""$'1\t2'"\" 2" "$actual"
}

test_ecmd_escapes_nl() {
    actual="$(ecmd "1" $'1\n2' "2")"
    assertEquals "1 \""$'1\n2'"\" 2" "$actual"
}

test_ecmd_escapes_cr() {
    actual="$(ecmd "1" $'1\r2' "2")"
    assertEquals "1 \""$'1\r2'"\" 2" "$actual"
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

test_eqexec_hides_stdout() {
    actual_output="$(eqexec echo test message)"
    assertEquals "" "$actual_output"
}

test_eqexec_hides_stderr() {
    actual_output="$(eqexec echo test message 1>&2)"
    assertEquals "" "$actual_output"
}

test_eqexec_hides_return_code() {
    eqexec false
    actual_error_code="$?"
    assertEquals "0" "$actual_error_code"
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
    ELOG_COLOR_ERROR="(red)"
    ELOG_COLOR_QUOTE="(yellow)"
    ELOG_COLOR_RESET="(reset)"
    actual_output="$(eexec mkdir / 2>&1)"
    ELOG_INDENT=""
    ELOG_COLOR_ERROR=""
    ELOG_COLOR_QUOTE=""
    ELOG_COLOR_RESET=""
    read -r -d '' expected_output << EOF
 (red)*(reset)   Process has failed with error code 1: mkdir /
     (yellow)>(reset) mkdir: /: Is a directory
EOF
    assertEquals "output" " $expected_output" "$actual_output"
}

source ./shunit2
