#!/usr/bin/env fish
# CLab notification profile script for fish shell
# This script will be sourced automatically when fish users log in

# Only run for interactive shells
if status is-interactive
    # Check if clab-notify command exists
    if command -v clab-notify >/dev/null 2>&1
        # Run the notification script
        clab-notify
    end
end
