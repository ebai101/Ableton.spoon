#!/usr/bin/env zsh
echo "$1" | nc -u -w 0 0.0.0.0 42069

