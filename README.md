# Gentoo AMI Builder

## Features

- One line command to create bootable Gentoo AMI images.
- Could setup all needed block device drivers to boot instance (NVMe etc).
- Could setup all needed network drivers to have network after boot (IXGBEVF, ENA etc).
- Minimalistic, only mandatory packages will be installed to get bootable system.
  System eats just ~50 MB of RAM after boot.
- Has minimalistic amazon-ec2-init script that could bootstrap hostname and ssh keys.
- Uses amazon-provided kernel config as basis.
- Build time is around 30-40 minutes (on 8 cores instance).
- Highly customizable, open source and free :-)
- Nice progress reporting with advanced error handling.
- Supports HVM virtualization type (PVM is not supported).
- Supports all known types of instances.
- Supports OpenRC and Systemd profiles.
- Supports experimental 17.1 amd64 profiles.

## Prerequisites

- AWS account.
- AWS user with enabled programmatic access.
- Locally installed and configured aws cli:
  <https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html>
- openssh, bash, curl, grep, sed, coreutils
- User should have these permissions:
  - ec2:RunInstances
  - ec2:TerminateInstances
  - ec2:DescribeInstances
  - ec2:CreateImage
  - ec2:DeregisterImage
  - ec2:DescribeImages
  - ec2:DeleteSnapshot
  - sts:GetCallerIdentity

This policy could be used to grant AWS user all needed permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:RunInstances",
                "ec2:TerminateInstances",
                "ec2:DescribeInstances",
                "ec2:CreateImage",
                "ec2:DeregisterImage",
                "ec2:DescribeImages",
                "ec2:DeleteSnapshot",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## Gentoo Stage3 Tarballs

Available Gentoo stage3 tarballs that could be theoretically used for bootstrap
and that are compatible with EC2 hardware as of 2018-08-12 are:

- **[?]** amd64-hardened+nomultilib (**amd64** arch)
- **[?]** amd64-hardened-selinux+nomultilib (**amd64** arch)
- **[?]** amd64-hardened-selinux (**amd64** arch)
- **[?]** amd64-hardened (**amd64** arch)
- **[?]** amd64-nomultilib (**amd64** arch)
- **[V]** amd64-systemd (**amd64** arch)
- **[?]** amd64-uclibc-hardened (**amd64** arch)
- **[?]** amd64-uclibc-vanilla (**amd64** arch)
- **[V]** amd64 (**amd64** arch)
- **[?]** x32 (**amd64** arch)
- **[X]** i486 (**x86** arch)
- **[X]** i686-hardened (**x86** arch)
- **[X]** i686-systemd (**x86** arch)
- **[X]** i686-uclibc-hardened (**x86** arch)
- **[X]** i686-uclibc-vanilla (**x86** arch)
- **[X]** i686 (**x86** arch)

Icons:

- [V] - verified, works
- [X] - verified, doesn't work in current version, but could be fixed
- [?] - not verified, could work or not

## Tested Configurations

- amd64 / c5.2xlarge (network driver ENA, block device driver NVMe)
- amd64 / c4.2xlarge (network driver IXGBEVF)
- amd64 / t2.2xlarge (unlimited cpu credits)
- OpenRC flavor
- systemd flavor

## Included Drivers

This script uses kernel config that is used in Amazon Linux instances with some
additional fixes:

- Some instances, like C3, have network only with IXGBEVF driver. Stock config
  has different name for driver so without fix it won't be enabled by default.
- Some instances, like C5, have network only with ENA driver. This driver need
  to be compiled during installation from sources provided by Amazon.
- Some instances, like C5, have NVMe block devices. NVMe driver need to be
  compiled into kernel to make sure that Gentoo will load it before mounting
  the root. There is also a set of scripts to properly detect disk device names
  because they are different for NVMe devices, /dev/nvmeXnY instead of /dev/xvdX.

## Caveats

Sometimes Gentoo server could work really slow, around 200Kb/sec, making whole
process much slower. You could terminate AMI builder and restart. New request
will be most-likely served from another instance and will be fast. Another
option is to change server in settings to the one that you trust.

AMI image creation could be also slow, up to 10-15 minutes usually for 20GB disk.

XEN PVM is not supported but technically could be implemented and it is not too
complex. Needs slightly different bootloader and kernel configuration.

x86 architecture is not supported. By the way support could be added. Not sure
if somebody needs x86 in cloud these days.

## Usage

Run `gentoo-ami-builder --help` for help.

Usually you just need to configure aws cli and run command below to get working
Gentoo AMI image:

```shell
gentoo-ami-builder --key-pair "Your Key Pair Name"
```

## Customization

Recommendation is to add extra actions needed for target image into phase 3 script.

## Examples

![Success p1](/screenshots/gentoo-amd64-c5-p1.png?raw=true)

![Success p2](/screenshots/gentoo-amd64-c5-p2.png?raw=true)

![Success p3](/screenshots/gentoo-amd64-c5-p3.png?raw=true)

![Failure](/screenshots/gentoo-x86-genkernel-error.png?raw=true)

## TODOs

- fix compatibility with x86
- customizable user phase passed via command line argument
- fix all shellcheck issues
- add debugging section in README
- fix PVM support
- test all gentoo profiles, blacklist unsupported
- better ssh connection wait function (see below)
- cover by unit tests

```shell
 *   Waiting until SSH will be up...
ssh: connect to host 34.200.218.187 port 22: Connection refused
```

## Reporting bugs

Please use the GitHub issue tracker for any bugs or feature suggestions:

<https://github.com/sormy/gentoo-ami-builder/issues>

## Contributing

Please submit patches to code or documentation as GitHub pull requests!

Contributions must be licensed under the MIT.

## Copyright

gentoo-ami-builder is licensed under the MIT. A copy of this license is included in the file LICENSE.
