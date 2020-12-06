#!/bin/sh

# Enumerates list of available Amazon Linux 2 AMIs for different regions and platforms.
# Some regions require to opt in through AWS console before being used (or queried).

regions="
    us-east-1
    us-east-2
    us-west-1
    us-west-2
    af-south-1
    ap-east-1
    ap-south-1
    ap-northeast-1
    ap-northeast-2
    ap-southeast-1
    ap-southeast-2
    ca-central-1
    eu-central-1
    eu-west-1
    eu-west-2
    eu-west-3
    eu-north-1
    eu-south-1
    me-south-1
    sa-east-1
"

architectures="
    x86_64
    arm64
"

printf "region\t\tarch\ttimestamp\t\t\tami\t\t\tname\n"

for region in $regions; do
    for arch in $architectures; do
        ami=$(aws ec2 describe-images \
            --region "$region" \
            --filters "Name=owner-alias,Values=amazon" \
                    "Name=name,Values=amzn2-ami-hvm-2.0.*-$arch-gp2" \
            --query "reverse(sort_by(Images, &CreationDate))[0].{Architecture: Architecture, CreationDate: CreationDate, ImageId: ImageId, Name: Name}" \
            --output text 2> /dev/null)

        printf "%s\t%s\n" "$region" "${ami:-none}"
    done
done
