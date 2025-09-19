# Welcome Bonus Processing Script

This script processes welcome bonus rewards for all eligible users in the Nachna application.

## Overview

The `test_welcome_bonuses.py` script finds all users who haven't received a welcome bonus yet and awards them the configured welcome bonus amount.

## Features

- ✅ **Duplicate Prevention**: Only processes users who haven't received a welcome bonus
- ✅ **Dry Run Mode**: Test what would happen without making changes
- ✅ **Batch Processing**: Process users in configurable batches to avoid overwhelming the system
- ✅ **Force Mode**: Override duplicate prevention (use with caution!)
- ✅ **Progress Tracking**: Real-time progress with detailed statistics
- ✅ **Error Handling**: Graceful handling of failures with detailed logging
- ✅ **Safety Checks**: Confirmation prompts for dangerous operations

## Usage

### Basic Usage

```bash
# Process welcome bonuses for eligible users
python scripts/test_welcome_bonuses.py

# Dry run to see what would happen
python scripts/test_welcome_bonuses.py --dry-run

# Process in smaller batches
python scripts/test_welcome_bonuses.py --batch-size 10

# Force process ALL users (dangerous!)
python scripts/test_welcome_bonuses.py --force
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--dry-run` | Show what would be done without making changes | False |
| `--batch-size N` | Process N users at a time | 50 |
| `--force` | Process ALL users regardless of existing bonuses | False |

## Examples

### 1. Safe Testing (Recommended First)
```bash
# See what would happen without making changes
python scripts/test_welcome_bonuses.py --dry-run --batch-size 5
```

### 2. Live Processing
```bash
# Process all eligible users in batches of 25
python scripts/test_welcome_bonuses.py --batch-size 25
```

### 3. Force Processing (Use with Caution!)
```bash
# Process EVERY user, even those with existing bonuses
# This will likely create duplicates - use only if you know what you're doing!
python scripts/test_welcome_bonuses.py --force --batch-size 10
```

## Output

The script provides detailed output including:

- 📊 **Statistics**: Total processed, successful, failed, and success rate
- ✅ **Success Messages**: Confirmation for each successful bonus award
- ❌ **Error Messages**: Detailed error information for failed awards
- 📦 **Batch Progress**: Progress updates for each batch
- 🎯 **Final Summary**: Complete statistics and recommendations

## Safety Features

### Duplicate Prevention
- Automatically detects users who already have welcome bonuses
- Skips processing for users with existing bonuses
- Uses database-level queries for accuracy

### Confirmation Prompts
- Force mode requires explicit confirmation
- Clear warnings about potential duplicate creation

### Error Recovery
- Individual user failures don't stop the entire process
- Detailed error logging for troubleshooting
- Graceful handling of network/database issues

## Configuration

The welcome bonus amount is configured in `app/config/settings.py`:

```python
reward_welcome_bonus: float = 100.0  # Welcome bonus in rupees
```

## Exit Codes

- `0`: Success (all bonuses processed successfully)
- `1`: Partial failure (some bonuses failed)
- `130`: Interrupted by user (Ctrl+C)

## Troubleshooting

### Common Issues

1. **"No eligible users found"**
   - All users already have welcome bonuses
   - Use `--force` if you want to override (dangerous!)

2. **Import errors**
   - Ensure you're running from the project root directory
   - Check that all required dependencies are installed

3. **Database connection errors**
   - Verify MongoDB is running
   - Check connection string in configuration

### Logs

The script provides detailed logging. Check the output for:
- User processing status
- Error messages and stack traces
- Batch completion statistics
- Final summary with recommendations

## Best Practices

1. **Always run dry-run first** to understand the impact
2. **Start with small batch sizes** for initial testing
3. **Monitor the process** especially for large user bases
4. **Backup database** before running on production
5. **Use force mode sparingly** and only when necessary

## Technical Details

- Uses MongoDB aggregation pipeline for efficient user filtering
- Implements proper error handling and logging
- Supports concurrent processing with configurable batch sizes
- Integrates with existing reward system architecture
