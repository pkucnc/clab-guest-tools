#!/bin/bash
# CLab notification profile script for bash/sh
# This script will be sourced automatically when users log in

# Only run for interactive shells
if [[ $- == *i* ]]; then
    # Check if clab-notify command exists
    if command -v clab-notify >/dev/null 2>&1; then
        # Run the notification script
        clab-notify
    fi
fi
