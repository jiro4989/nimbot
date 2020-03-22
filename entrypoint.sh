#!/bin/sh

set -eu

nimble install -Y
/root/.nimble/bin/$1
