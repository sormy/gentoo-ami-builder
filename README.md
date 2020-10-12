# Gentoo AMI Builder

## Features

- One line command to create bootable Gentoo AMI images.
- Can use spot instances to save up to 50% on bill.
- One image build costs ~20 cents (as of 2020-10-11) with spot instance.
- Build time is around 30-40 minutes (on 8 cores instance).
- Configures all needed block device drivers to boot instance (NVMe etc).
- Configures all needed network drivers to have network after boot (IXGBEVF, ENA etc).
- Minimalistic, only mandatory packages will be installed to get bootable system.
  System eats just ~50 MB of RAM after boot.
- Has minimalistic amazon-ec2-init script that can bootstrap hostname and ssh keys.
- Uses amazon provided kernel config as basis.
- Nice progress reporting with advanced error handling.
- Should support all known types of instances.
- Supports HVM virtualization type.
- Supports OpenRC and Systemd profiles.
- Supports experimental 17.1 amd64 profiles.
- It is Gentoo, so you can tune and configure everything.
- Highly customizable, open source and free :-)

## Prerequisites

- AWS account.
- AWS user with enabled programmatic access.
- Locally installed and configured aws cli:
  <https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html>
- openssh, bash, curl, grep, sed, coreutils
- These permissions to run on on-demand instances:
  - ec2:RunInstances
  - ec2:TerminateInstances
  - ec2:DescribeInstances
  - ec2:CreateImage
  - ec2:DeregisterImage
  - ec2:DescribeImages
  - ec2:DeleteSnapshot
  - sts:GetCallerIdentity
- These additional permissions to run on spot instances:
  - ec2:DescribeSpotInstanceRequests
  - ec2:RequestSpotInstances
  - iam:CreateServiceLinkedRole

Usually the easiest solution is to just temporarily add AWS managed policy
"AdministratorAccess" to your user.

Alternatively, this policy can be used to grant AWS user all needed permissions:

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
                "ec2:DescribeSpotInstanceRequests",
                "ec2:DeleteSnapshot",
                "ec2:RequestSpotInstances",
                "iam:CreateServiceLinkedRole",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## Usage

Usually you just need to configure aws cli and run command below to get working
default Gentoo AMI amd64 / OpenRC image:

```shell
git checkout https://github.com/sormy/gentoo-ami-builder
cd gentoo-ami-builder
./gentoo-ami-builder.sh --key-pair "Your Key Pair Name"
```

Wait for ~40 minutes and you will discover an AMI in AWS console that you can
use to start new instances.

NOTE: Spot instances are used by default to save on bill.

The most important options you can use:

- `--key-pair` - mandatory to access EC2 builder instance
- `--gentoo-stage3` - pick what stage3 to use
- `--gentoo-profile` - switch profile after installing stage3 (rebuild is slow)
- `--gentoo-image-name` - what name to use to save AMI
- `--user-phase` - local script to sideload and execute to bootstrap additional
  tools into Gentoo AMI image

Run `gentoo-ami-builder --help` to see full list of available options.

Builder by default is doing a few reboots to confirm that instance is bootable
and accessible over network.

**Doesn't work? Please file a bug immediately!**

## Customization

Use `--user-phase` option to pass custom script that can do any kind of special
configuration, install needed packages, anything that is needed to make a base
AMI for your use cases.

## Stage3

Here are all available Gentoo stage3 tarballs that are theoretically compatible
with EC2 hardware as of 2020-10-11:

| Stage3                            | Profile | Arch  | Status     | Verified On |
|-----------------------------------|---------|-------|------------|-------------|
| amd64-hardened+nomultilib         | default | amd64 | :question: |             |
| amd64-hardened-selinux+nomultilib | default | amd64 | :question: |             |
| amd64-hardened-selinux            | default | amd64 | :question: |             |
| amd64-hardened                    | default | amd64 | :ok:       |             |
| amd64-musl-hardened               | default | amd64 | :question: |             |
| amd64-musl-vanilla                | default | amd64 | :question: |             |
| amd64-nomultilib                  | default | amd64 | :question: |             |
| amd64-systemd                     | default | amd64 | :ok:       |             |
| amd64-uclibc-hardened             | default | amd64 | :question: |             |
| amd64-uclibc-vanilla              | default | amd64 | :question: |             |
| amd64                             | default | amd64 | :ok:       | 2020-10-11  |
| x32                               | default | amd64 | :question: |             |
| i486                              | default | x86   | :x:        |             |
| i686-hardened                     | default | x86   | :x:        |             |
| i686-musl-vanilla                 | default | x86   | :x:        |             |
| i686-systemd                      | default | x86   | :x:        |             |
| i686-uclibc-hardened              | default | x86   | :x:        |             |
| i686-uclibc-vanilla               | default | x86   | :x:        |             |
| i686                              | default | x86   | :x:        |             |
| arm64-systemd                     | default | arm64 | :x:        |             |
| arm64                             | default | arm64 | :x:        |             |

Icons:

- :ok: - verified by maintainers, works
- :x: - verified by maintainers, doesn't work in current version,
  but could be fixed, PRs are welcome
- :question: - not verified, could work or not, please submit a PR if you have confirmed
  that it works or if it doesn't work

## EC2 Instance Type

The build is tested to be working well on these instance types:

- amd64 / c5.2xlarge (network driver ENA, block device driver NVMe)
- amd64 / c4.2xlarge (network driver IXGBEVF)
- amd64 / t2.2xlarge (unlimited cpu credits)

Build process on slow instances could fail (due to lack of RAM) or could take
a lot of time (due to low CPU performance and low number of cores).

## Init System

This builder has been tested to work well with two init systems:

- OpenRC (default)
- Systemd

## Kernel Config

This script uses kernel config that is used in Amazon Linux instances. This is
a reason why bootstrap should be performed using Amazon Linux distribution, to
steal kernel config :-)

By the way, there are some additional fixes performed by this script:

- Some instances, like C4, have network only with IXGBEVF driver. Stock config
  has different name for driver so without fix it won't be enabled by default.
- Some instances, like C5, have network only with ENA driver. This driver need
  to be compiled during installation from sources provided by Amazon.
- Some instances, like C5, have NVMe block devices. NVMe driver need to be
  compiled into kernel to make sure that Gentoo will load it before mounting
  the root. There is also a set of scripts to properly detect disk device names
  because they are different for NVMe devices, /dev/nvmeXnY instead of /dev/xvdX.

## FAQ

### Downloading stage3 is slow

Sometimes Gentoo distfile server could work slow, around 200Kb/sec, making whole
process much slower. You could terminate AMI builder and restart. New request
will be most-likely served from another distfile server and will be fast. Another
option is to change distfile server in settings to the one that you trust.

### AMI image creation is slow

AMI image creation could be slow, up to 10-15 minutes usually for 20GB disk.

### What about PVM instances?

PVM is used on old instance types C1, C3, HS1, M1, M3, M2, and T1 that are
not highly available these days and will be all eventually replaced with modern
HVM instances.

Read more: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/virtualization_types.html

PVM is not supported at this time but technically can be implemented. Need to
configure slightly differently bootloader and kernel.

Feel free to submit a PR that adds PVM support.

### What about x86 support?

x86 architecture is not supported at this time but technically can be implemented.

Feel free to submit a PR that adds x86 support.

### Why can't we just use aws ec2 import-image?

AWS cli has a command `aws ec2 import-image` that is designated to import
existing disk images, however, there are a few reason why it is not used in this
builder:

- It is picky to image format. Only raw images are generally acceptable without
  compatibility issues. For vmdk created with qemu-img it produces this error:
  "ClientError: Disk validation failed [Unsupported VMDK File Format]"
- It does STRICT validation of image, including kernel version, so you can get:
  "ClientError: Unsupported kernel version 5.4.66-gentoo-x86_64"
- It is slower because source image is converted from source format to the format
  used by AWS.
- It requires to upload image file to s3 before the process can be executed.
  This also makes process slower and adds additional cost for big images.

This script doesn't have these limitations!

## Examples

![Success p1](/screenshots/gentoo-amd64-c5-p1.png?raw=true)

![Success p2](/screenshots/gentoo-amd64-c5-p2.png?raw=true)

![Success p3](/screenshots/gentoo-amd64-c5-p3.png?raw=true)

![Failure](/screenshots/gentoo-x86-genkernel-error.png?raw=true)

## Reporting Issues

Please use the GitHub issue tracker for any bugs or feature suggestions:

<https://github.com/sormy/gentoo-ami-builder/issues>

## Contributing

Contributions are very welcome!

Please take a look on `TODO.md` to see what things can be improved.

Please submit fixes or improvements as GitHub pull requests!

Contributions must be licensed under the MIT.

## Copyright

gentoo-ami-builder is licensed under the MIT.

A copy of this license is included in the file LICENSE.
