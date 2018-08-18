#!/bin/bash

# ENA kernel module source repo.
ENA_REPO_NAME="sormy/gentoo"
ENA_REPO_BRANCH="master"
ENA_NAME="ena"
ENA_GROUP="net-misc"
ENA_PKG="$ENA_GROUP/$ENA_NAME"
ENA_VERSION="1.5.3"

create_local_overlay_with_ena_module() {
    # global ENA_REPO_NAME
    # global ENA_REPO_BRANCH
    # global ENA_NAME
    # global ENA_PKG
    # global ENA_VERSION

    local target="$1"

    eexec mkdir -p "$target/etc/portage/repos.conf"

    cat > "$target/etc/portage/repos.conf/local.conf" << END
[local]
location = /usr/local/portage
masters = gentoo
auto-sync = no
END

    eexec mkdir -p "$target/usr/local/portage"

    eexec mkdir -p "$target/usr/local/portage/metadata"

    cat > "$target/usr/local/portage/metadata/layout.conf" << END
repo-name = local
masters = gentoo
thin-manifests = true
END

    eexec mkdir -p "$target/usr/local/portage/$ENA_PKG"

    eexec curl \
        -o "$target/usr/local/portage/$ENA_PKG/$ENA_NAME-$ENA_VERSION.ebuild" \
        "https://raw.githubusercontent.com/$ENA_REPO_NAME/$ENA_REPO_BRANCH/$ENA_PKG/$ENA_NAME-$ENA_VERSION.ebuild" \
        -o "$target/usr/local/portage/$ENA_PKG/Manifest" \
        "https://raw.githubusercontent.com/$ENA_REPO_NAME/$ENA_REPO_BRANCH/$ENA_PKG/Manifest"
}
