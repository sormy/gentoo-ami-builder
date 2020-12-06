# Gentoo AMI Builder

## Features

- Single simple command line tool to create bootable Gentoo AMI images.
- Uses spot instances by default to save up to 50% on bill. One image build
  usually costs less than ~20 cents (as of 2020-10-14).
- Supports any customization and any kernel version (`aws ec2 import-image`
  supports only fixed predefined list of kernels).
- Build time is around ~50 mins for amd64 and ~90 mins for arm64 with default
  instance types (as of 2020-10-14).
- Steals kernel config from Amazon Linux so configures all needed kernel modules,
  including block device drivers to boot instance (NVMe etc) and network drivers
  to have network after boot (IXGBEVF, ENA etc).
- Should support all known HVM types of instances (including amd64 and arm64).
- Minimalistic, only mandatory packages will be installed to get bootable system.
  System eats just ~50 MB of RAM after boot.
- Uses minimalistic ec2-init script that can bootstrap hostname, ssh keys and
  run shell script from EC2 user metadata similar to how cloud-init do that.
- Nice, not too verbose, progress reporting with advanced verbose error handling.
- Supports OpenRC and Systemd init systems.
- Supports profile switching, including upgrade to 17.1 from 17.0 amd64 profiles.
- Highly customizable (well, it is Gentoo), open source and free :-)
- Multi-region support.
- Automatic fresh Amazon Linux 2 image detection.

## How it works

The builder replaces Amazon Linux with Gentoo Linux using second volume as
temporary buffer (aux disk) in a few phases:

- Phase 1: Prepare Instance - Spawn instance with Amazon Linux and two volumes
- Phase 2: Prepare Root - Prepare second volume and install Gentoo stage3 to it
- Phase 3: Build Root - Make Gentoo on second volume bootable
- Phase 4: Switch Root - Reconfigure bootloader and reboot from second volume
- Phase 5: Migrate Root - Clone second volume to first and reboot from first volume
- Phase 6: Build AMI - Request AMI from first volume

The build process is orchestrated by builder so ensure that network connection
is stable, otherwise, the process could crash.

"Build Root" has bottleneck on CPU.

"Migrate Root" has bottleneck on disk IO bandwidth (cloning volume to volume).

"Build AMI" has bottleneck on AWS, not controllable on our side.

Using more powerfull instance type helps to make Phase 3 faster, however, it
doesn't have noticeable effect on other phases.

The builder is configured to use default instance types that are well-known to
have good build time / cost ratio. You can pick another instance type to speedup
the build or to make build process cheaper. Keep in mind, build on instance with
less than 2GB of RAM will most-likely fail on kernel compilation phase.

## Prerequisites

- Locally installed and configured
  [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html).
- Linux or macOS with openssh, bash, curl, coreutils
- AWS account
- SSH key generated in AWS console or imported into AWS account (Key Pair)
- AWS security group that allows incoming connections on 22 port
- AWS user with enabled programmatic access
  - Permissions to build on on-demand instances:
    - ec2:RunInstances
    - ec2:TerminateInstances
    - ec2:DescribeInstances
    - ec2:CreateImage
    - ec2:DeregisterImage
    - ec2:DescribeImages
    - ec2:DeleteSnapshot
    - sts:GetCallerIdentity
  - Additional permissions to build on spot instances:
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

You will find an AMI in AWS console once the builder will finish the process.
The image can be used to start any instance for the same platform.

NOTE: Spot instances are used by default to save on bill.

The most important options:

- `--region` - custom AWS region (by default it is `us-east-1`)
- `--security-group` - custom security group to attach to spawn instance
- `--key-pair` - required to access EC2 builder instance over SSH
- `--gentoo-stage3` - pick what stage3 to use, usually, `amd64` or `arm64`
- `--gentoo-image-name` - what AMI name prefix to use
- `--user-phase` - local script to sideload and execute to bootstrap additional
  tools into Gentoo AMI image

Run `gentoo-ami-builder --help` to see full list of available options.

**Doesn't work? Please file a bug and we will take care of it!**

## Troubleshooting

**Can't connect over SSH during prepare instance phase**

Check if default security group "default" has enabled incoming access on 22 port
form 0.0.0.0 or your IP address.

**Timeout on "Waiting until AMI image will be available"**

The time that takes to create image depends on multiple factors, including region,
time of the day, day of the week, type of instance, size of volume etc.

Failing on last step doesn't mean that image creation won' be finished at all,
most likely it will finish, but a bit later. You can still monitor progress in
AWS console.

If you are experience continues failures when default 30 minutes is not enough,
then submit an issue on the tracker.

## Customization

Use `--user-phase` option to pass custom script that can do any kind of special
configuration, install needed packages, anything that is needed to make a base
AMI for your use cases.

## Stage3

Here are all available Gentoo stage3 tarballs that are theoretically compatible
with EC2 hardware (as of 2020-10-14):

| Stage3                            | Profile | Arch  | Status     | Last Verified         |
|-----------------------------------|---------|-------|------------|-----------------------|
| amd64-hardened+nomultilib         | default | amd64 | :ok:       | v1.1.0 on 2020-10-14  |
| amd64-hardened-selinux+nomultilib | default | amd64 | :ok:       | v1.1.0 on 2020-10-14  |
| amd64-hardened-selinux            | default | amd64 | :ok:       | v1.1.0 on 2020-10-14  |
| amd64-hardened                    | default | amd64 | :ok:       | v1.1.0 on 2020-10-14  |
| amd64-musl-hardened               | default | amd64 | :x:        | v1.1.0 on 2020-10-14  |
| amd64-musl-vanilla                | default | amd64 | :x:        | v1.1.0 on 2020-10-14  |
| amd64-nomultilib                  | default | amd64 | :ok:       | v1.1.0 on 2020-10-14  |
| amd64-systemd                     | default | amd64 | :ok:       | v1.1.0 on 2020-10-14  |
| amd64-uclibc-hardened             | default | amd64 | :x:        | v1.1.0 on 2020-10-14  |
| amd64-uclibc-vanilla              | default | amd64 | :x:        | v1.1.0 on 2020-10-14  |
| amd64                             | default | amd64 | :ok:       | v1.1.0 on 2020-10-14  |
| x32                               | default | amd64 | :ok:       | v1.1.1 on 2020-10-20  |
| i486                              | default | x86   | :x:        |                       |
| i686-hardened                     | default | x86   | :x:        |                       |
| i686-musl-vanilla                 | default | x86   | :x:        |                       |
| i686-systemd                      | default | x86   | :x:        |                       |
| i686-uclibc-hardened              | default | x86   | :x:        |                       |
| i686-uclibc-vanilla               | default | x86   | :x:        |                       |
| i686                              | default | x86   | :x:        |                       |
| arm64-systemd                     | default | arm64 | :ok:       | v1.1.0 on 2020-10-14  |
| arm64                             | default | arm64 | :ok:       | v1.1.0 on 2020-10-14  |

Status:

- :ok: - it works, verified by maintainers
- :x: - it doesn't work, verified by maintainers (PRs are welcome!)
- :question: - not verified, could work or not, please submit a PR to update this
  table if you have tested the stage (PRs for fixes are also welcome!)

Problems:

- x86 (stable) - needs x86 kernel config generated from amd64 config
- musl (exp) - kernel compilation fails (dive deep)
- uclibc (exp) - gettext compilation fails during world update (dive deep)

## EC2 Instance Type

The build is tested to be working well on these instance types:

- amd64 / c5.2xlarge (network ENA, block NVMe, MBR boot)
- amd64 / c4.2xlarge (network IXGBEVF, MBR boot)
- amd64 / t2.2xlarge (unlimited cpu credits)
- arm64 / a1.2xlarge (network ENA, block NVME, EFI boot)

Build process on slow instances could fail (due to lack of RAM) or could take
a lot of time (due to low CPU performance).

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
  the root.

NOTE: EFA driver is not available yet. PRs are welcome!

## FAQ

### Downloading stage3 is slow

Sometimes Gentoo distfile server could work slow, around 200Kb/sec, making whole
process much slower. You could terminate AMI builder and restart. New request
will be most-likely served from another distfile server and will be fast. Another
option is to change distfile server in settings to the one that you trust.

NOTE: Ensure that there are no any not terminated instances running if build
process has been terminated.

### AMI image creation is slow

AMI image creation could be slow, usually it is up to 10-20 minutes for 20GB
volume.

### What about PVM instances?

PVM is used on old instance types C1, C3, HS1, M1, M3, M2, and T1 that are
not highly available these days and will be all eventually replaced with modern
HVM instances.

Read more: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/virtualization_types.html

PVM is not supported at this time but technically can be implemented. Need to
configure a bit differently bootloader and kernel.

Feel free to submit a PR that adds PVM support.

### What about x86 support?

x86 architecture is not supported at this time but technically can be implemented.

Please also consider using Gentoo x32 stage3 that has benefits of both amd64
and x86 worlds.

Feel free to submit a PR that adds x86 support.

### Why can't we just use aws ec2 import-image?

AWS cli has a command `aws ec2 import-image` that is designated to import
existing disk images, however, there are a few reasons why it is not used in
this builder:

- It is picky to image content. It does STRICT validation of image, including
  kernel version, so you can easy get something like message below:
  "ClientError: Unsupported kernel version 5.4.66-gentoo-x86_64"
- It is picky to image format. Only raw images are generally acceptable without
  compatibility issues. For vmdk created with qemu-img it produces this error:
  "ClientError: Disk validation failed [Unsupported VMDK File Format]"
- It requires to upload image file to s3 before the process can be executed.
  This also makes process slower and adds additional cost for big images.
- It is slower because source image is converted from source format to the format
  used by AWS.

This builder script doesn't have these limitations but the procedure it performs
is more complex.

## Examples

![Success p1](./examples/gentoo-amd64-c5-p1.png?raw=true)

![Success p2](./examples/gentoo-amd64-c5-p2.png?raw=true)

![Success p3](./examples/gentoo-amd64-c5-p3.png?raw=true)

![Failure](./examples/gentoo-x86-genkernel-error.png?raw=true)

Build log examples:
[amd64](./examples/gentoo-amd64.txt?raw=true)
[amd64-systemd](./examples/gentoo-amd64-systemd.txt?raw=true)
[arm64](./examples/gentoo-arm64.txt?raw=true)
[arm64-systemd](./examples/gentoo-arm64-systemd.txt?raw=true)
[x32](./examples/gentoo-x32.txt?raw=true)

## Reporting Issues

Gentoo is rolling release system, AWS is also releasing new instance types
periodically, so the builder that worked Yesterday could stop working Today.
This application requires periodical maintenance to ensure that it is still
working on latest Gentoo and new AWS instance type. Please file a bug if you
are experiencing an issue and we will take care of it.

Please use the GitHub [issue tracker](https://github.com/sormy/gentoo-ami-builder/issues)
for any bugs or feature suggestions.

## Contributing

Contributions are very welcome!

Please take a look on [TODO](./TODO.md) to see what things could be improved.

Please submit fixes or improvements as GitHub pull requests!

For code changes please consider doing 4 default builds to verify that there
are no any regressions: amd64, amd64-systemd, arm64 and arm64-systemd.

Contributions must be licensed under the MIT.

## Copyright

gentoo-ami-builder is licensed under the MIT.

A copy of this license is included in the file LICENSE.txt
