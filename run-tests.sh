#!/bin/bash

[ -f "shunit2" ] || wget https://raw.githubusercontent.com/kward/shunit2/master/shunit2

./tests/test-elib.sh
