#!/bin/sh

set -eu

export PATH=~/.nimble/bin:$PATH
nimble install -Y
$1
