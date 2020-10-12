Below is the list of things that require additional work.

Contributions for these fixes/improvements are very welcome ;-)

- automated builds every week, publish AMIs to public
- integration testing for every build - on each compatible instance type
- fix compatibility with x86
- add compatibility with arm64
- fix all shellcheck issues
- add debugging section in README
- fix PVM support
- test all gentoo profiles, blacklist unsupported
- better ssh connection wait function (see below)
- cover by unit tests
- rebuild type for world update (full or simple)
- update ec2-init
- update readme regarding arm64
- simplification, need to make it easier
- add efa driver support: https://github.com/amzn/amzn-drivers/tags
  https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html

```shell
 *   Waiting until SSH will be up...
ssh: connect to host 34.200.218.187 port 22: Connection refused
```
