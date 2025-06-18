#!/bin/bash

# Workshop Refresh Script
# Runs every 6 hours via cron job to update workshop data from various studios

# Set script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root directory
cd "$PROJECT_ROOT"

# Create log file with timestamp
LOG_FILE="$PROJECT_ROOT/logs/workshop_refresh_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$PROJECT_ROOT/logs"

# Load environment variables if .env file exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Loading environment variables from .env file" | tee -a "$LOG_FILE"
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
fi

# Check for required environment variables
if [ -z "$OPENAI_API_KEY" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: OPENAI_API_KEY environment variable is not set" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] This may cause some scripts to fail" | tee -a "$LOG_FILE"
fi

# Function to log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to run command with error handling
run_command() {
    local cmd="$1"
    local description="$2"
    
    log_message "Starting: $description"
    log_message "Command: $cmd"
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_message "SUCCESS: $description completed"
        return 0
    else
        log_message "ERROR: $description failed with exit code $?"
        return 1
    fi
}

# Start refresh process
log_message "=== Workshop Refresh Process Started ==="
log_message "Project Root: $PROJECT_ROOT"
log_message "Log File: $LOG_FILE"

# Initialize error counter
ERROR_COUNT=0

# Set Python interpreter to use virtual environment
PYTHON_CMD="$PROJECT_ROOT/venv/bin/python"

# Verify python interpreter exists
if [ ! -f "$PYTHON_CMD" ]; then
    log_message "ERROR: Python interpreter not found at $PYTHON_CMD"
    log_message "Please ensure virtual environment is set up correctly"
    exit 1
fi

log_message "Using Python interpreter: $PYTHON_CMD"

# Run workshop population scripts sequentially
run_command "$PYTHON_CMD scripts/populate_workshops.py --env prod --studio manifest --ai gemini" "Manifest by TMN studio workshop population"
if [ $? -ne 0 ]; then ((ERROR_COUNT++)); fi

run_command "$PYTHON_CMD scripts/populate_workshops.py --env prod --studio vins --ai gemini" "Vins studio workshop population"
if [ $? -ne 0 ]; then ((ERROR_COUNT++)); fi

run_command "$PYTHON_CMD scripts/populate_workshops.py --env prod --studio dna --ai gemini" "DNA studio workshop population"
if [ $? -ne 0 ]; then ((ERROR_COUNT++)); fi

run_command "$PYTHON_CMD scripts/populate_workshops.py --env prod --studio danceinn --ai gemini" "Dance Inn studio workshop population"
if [ $? -ne 0 ]; then ((ERROR_COUNT++)); fi

run_command "$PYTHON_CMD scripts/manual_populate_workshops.py" "Manual workshop population"
if [ $? -ne 0 ]; then ((ERROR_COUNT++)); fi

# Summary
log_message "=== Workshop Refresh Process Completed ==="
log_message "Total errors: $ERROR_COUNT"

if [ $ERROR_COUNT -eq 0 ]; then
    log_message "All workshop refresh operations completed successfully!"
    exit 0
else
    log_message "Workshop refresh completed with $ERROR_COUNT errors. Check log for details."
    exit 1
fi
