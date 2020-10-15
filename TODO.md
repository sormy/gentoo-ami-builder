Below is the list of things that could be improved.

- automated builds every week, publish AMIs to public
- integration testing for every build - on each compatible instance type
- fix x32 support
- fix x86 support (low priority)
- fix musl support
- fix uclibc support
- fix PVM support (low priority)
- test each Gentoo profile and build table with test results (similar to stage3 test)
- fix all shellcheck issues and annotate false alarms
- add debugging section in README
- better ssh connection wait function (produces noise on console)
- cover by unit tests
- rebuild type for world update (full or simple)
- update ec2-init
- simplification, need to make it easier
- add EFA driver support: https://github.com/amzn/amzn-drivers/tags
  https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html
- nvme_core.io_timeout=4294967295 is it needed on Gentoo?
- mount read-only and sync disk buffers before taking snapshot
- dump in the end how much of hard drive is used to hint how much space can be
  saved on image size
- fix double domain name on boot console:
  `This is ip-172-31-82-95.ec2.internal.ec2.internal (Linux aarch64 5.4.66-gentoo-arm64 ...`
- fix system log errors from grub on EFI
  - `[0m[37m[40merror: serial port 'com0' isn't found.`
  - `error: terminal 'serial' isn't found.`
  - seems like serial is needed for amd64 (PC) but not for arm64 (EFI)
- fix warning that ena is already loaded on EFI:
  `modprobe: ERROR: could not insert 'ena': Module already in kernel`
- may be disable colors in OpenRC to have system log to look well in AWS
  System Log console
- add custom user configure phase support (before world update)
- add automatic etc-update call
- wait for image without timeout:
  - use `"pending"` as condition that everything is good
  - use `"completed"` as condition that AMI is done
  - use any other status as problematic
- may be install grub without chroot in phase 5?
- may be have an option to use rsync instead of dd to clone Gentoo from disk
  to disk - could be faster since only used space will be copied.
- add option to choose root filesystem type (ext4, xfs, btrfs etc)
- may be sideload giant shell script that will do all the stuff on the host and
  let builder script to just periodically check the status (this should help to
  avoid ssh connection error to break the build process)

ssh noise:

```shell
 *   Waiting until SSH will be up...
ssh: connect to host 34.200.218.187 port 22: Connection refused
```
