#!/bin/bash

# global CURL_OPTS
# global GENTOO_GPG_KEYS

download_distfile_safe() {
    # global CURL_OPTS
    # global GENTOO_GPG_KEYS

    local url="$1"
    local file="$2"

    local expected_hash
    local actual_hash
    local hash
    local hash_verified=0

    eexec curl $CURL_OPTS \
        -o "$file" "$url" \
        -o "$file.DIGESTS" "$url.DIGESTS"

    for hash in sha512 whirlpool; do
        expected_hash="$(grep -i "$hash" -A 1 < "$file.DIGESTS" \
            | grep -v '^[#-]' | grep -v '\.CONTENTS\.' | cut -d" " -f1)"

        if [ -n "$expected_hash" ]; then
            einfo "Verifying $hash hash..."

            actual_hash="$(openssl dgst -r -$hash "$file" | cut -d" " -f1)"

            if [ "$expected_hash" != "$actual_hash" ]; then
                eerror "$hash hash verification failed."
                eerror "Expected $hash: $expected_hash"
                eerror "Actual $hash: $actual_hash"
                exit 1
            else
                hash_verified=1
            fi
        fi
    done

    if [ "$hash_verified" = 0 ]; then
        eerror "Unable to find any applicable hash to verify"
        exit 1
    fi

    gpg_verify "$file.DIGESTS"

}
