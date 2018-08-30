#!/bin/bash

[ -f "shunit2" ] || curl -s -o shunit2 https://raw.githubusercontent.com/kward/shunit2/master/shunit2

./tests/test-elib.sh
