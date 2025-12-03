#!/bin/bash
################################################################################
# user-prompt-submit.sh
#
# Purpose: Hook that runs on UserPromptSubmit event
#          Triggers auto-context injection in background
#
# Event: UserPromptSubmit (every user message)
################################################################################

# Run auto-context injection (background, non-blocking)
~/.claude/hooks/auto-context-inject.sh &

exit 0
