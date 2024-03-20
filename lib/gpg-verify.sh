#!/bin/bash

# global GENTOO_GPG_KEYS
# global GENTOO_GPG_KEYS_FETCHED

gpg_verify() {
    # global GENTOO_GPG_KEYS
    # global GENTOO_GPG_KEYS_FETCHED

    local file="$1"

    # Mark these keys as trusted to avoid various gpg errors/warnings later.
    if [ ! "$GENTOO_GPG_KEYS_FETCHED" = "1" ]; then
      einfo "Fetching GPG keys..."
      eexec gpg --keyserver hkps://keys.gentoo.org \
        --recv-keys $GENTOO_GPG_KEYS \
        || edie "Fetching GPG keys failed."
      for KEY_ID in $GENTOO_GPG_KEYS ; do
        (echo 5; echo y; echo save) |
          eexec gpg --command-fd 0 --no-tty --no-greeting -q --edit-key "$KEY_ID" trust
      done
      eexec gpg --check-trustdb
      GENTOO_GPG_KEYS_FETCHED=1
    fi

    einfo "Verifying GPG signature for ${1} ..."

    eexec gpg --verify "${1}" \
        || edie "GPG signature verification failed."

    true
}
