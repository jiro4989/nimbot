#!/bin/bash

set -eu

sleep 2
nimble install -Y
$1
