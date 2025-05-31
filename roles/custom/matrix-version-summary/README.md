# Matrix Version Summary and History

This role tracks container version changes over time and provides tools to view and manage the version history.

## Features

- Records version changes of Matrix containers during playbook runs
- Maintains a history of changes with timestamps and users
- Displays version changes in a clean, formatted table
- Provides full history view for each service
- Supports filtering by service name
- Includes tools to manage history (clear, trim)
- **Automatic retention cleanup** - Removes history entries older than configured days
- **Dual retention policies** - Both count-based and date-based limits

## Configuration

The role supports the following configuration variables:

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `matrix_container_prefix` | `"matrix-"` | Container name prefix to filter for Matrix containers |
| `matrix_history_max_entries` | `100` | Maximum number of history entries to keep (count-based limit). Set to 0 for unlimited |
| `matrix_history_retention_days` | `365` | Number of days to retain history entries (date-based limit). Set to 0 for unlimited |
| `matrix_show_version_summary` | `true` | Enable/disable version summary display (legacy variable) |
| `matrix_version_summary_display` | `"{{ matrix_show_version_summary }}"` | Primary control for enabling/disabling version summary display |
| `matrix_versions_fact_file` | `"matrix_versions.fact"` | Filename for storing current version facts |
| `matrix_history_fact_file` | `"matrix_version_history.fact"` | Filename for storing version history facts |
| `matrix_table_style_unicode` | `true` | Use Unicode characters for table borders (set to false for ASCII-only) |

### Variable Precedence
- `matrix_version_summary_display` takes precedence over `matrix_show_version_summary`
- Both variables default to `true` if not explicitly set
- Setting either to `false` will disable the version summary display

## Usage

### View Version History

```bash
# View changes history (default mode)
ansible-playbook -i inventory/hosts roles/custom/matrix-version-summary/tasks/history_playbook.yml -e "target_host=your-matrix-server.com" -K

# View full service history
ansible-playbook -i inventory/hosts roles/custom/matrix-version-summary/tasks/history_playbook.yml -e "target_host=your-matrix-server.com view_mode=full" -K

# Filter for a specific service
ansible-playbook -i inventory/hosts roles/custom/matrix-version-summary/tasks/history_playbook.yml -e "target_host=your-matrix-server.com service_filter=matrix-synapse" -K
```

### Manage History

```bash
# Clear all version history (requires confirmation)
ansible-playbook -i inventory/hosts roles/custom/matrix-version-summary/tasks/clear_history_playbook.yml -e "target_host=your-matrix-server.com confirm_clear=yes" -K

# Trim history to maximum entries (requires confirmation)
ansible-playbook -i inventory/hosts roles/custom/matrix-version-summary/tasks/trim_history_playbook.yml -e "target_host=your-matrix-server.com confirm_trim=yes" -K

# Trim history to custom entry count
ansible-playbook -i inventory/hosts roles/custom/matrix-version-summary/tasks/trim_history_playbook.yml -e "target_host=your-matrix-server.com confirm_trim=yes matrix_history_max_entries=50" -K
```

### Configure Unlimited Retention

To disable retention limits entirely, set both parameters to 0 in your configuration:

```yaml
# In your host_vars or group_vars file
matrix_history_max_entries: 0      # Unlimited entry count
matrix_history_retention_days: 0   # Unlimited time retention
```

**Note**: When `matrix_history_max_entries` is set to 0, the trim playbook will refuse to run since trimming is not applicable for unlimited configurations.

## Retention Policies

The role implements dual retention policies that work together:

### Count-Based Retention
- **Parameter**: `matrix_history_max_entries` (default: 100)
- **Behavior**: Automatically keeps only the most recent N entries when adding new history
- **Unlimited**: Set to 0 to disable count-based limits (unlimited entries)
- **Trigger**: Applied during each playbook run when changes are recorded
- **Manual Control**: Use the trim playbook to manually apply count limits (not applicable when set to 0)

### Date-Based Retention  
- **Parameter**: `matrix_history_retention_days` (default: 365)
- **Behavior**: Automatically filters out entries older than N days when viewing/reading history
- **Unlimited**: Set to 0 to disable date-based filtering (unlimited retention)
- **Trigger**: Applied when viewing history or reading history data
- **Effect**: Old entries become invisible but remain in storage until manually cleared

### Storage Location
Version history is stored in Ansible local facts:
- **Current versions**: `/etc/ansible/facts.d/matrix_versions.fact`
- **Version history**: `/etc/ansible/facts.d/matrix_version_history.fact`

These files persist across playbook runs and system reboots.

## Execution Modes

The role supports two distinct execution modes:

### Full Playbook Execution (Normal Mode)
When the role runs as part of the complete `setup.yml` playbook:
- **Behavior**: Normal change tracking - compares "before" and "after" versions
- **Status Values**: `NEW`, `UPDATED`, `UNCHANGED`
- **History Recording**: Records actual version changes to history files
- **Use Case**: During normal Matrix service upgrades and deployments

### Status Check Mode (Tag-Only Execution)
When run independently with `--tags=matrix-version-summary`:
- **Behavior**: Status checking - displays current running versions without comparison
- **Status Values**: `CURRENT` (shows what's currently running)
- **History Recording**: Skipped - no phantom "changes" recorded
- **Use Case**: Quick status check of running service versions

```bash
# Normal execution (part of full playbook)
ansible-playbook -i inventory/hosts setup.yml

# Status check mode (tag-only execution)
ansible-playbook -i inventory/hosts setup.yml --tags=matrix-version-summary
```

The role automatically detects the execution context and adjusts its behavior accordingly, preventing the logical inconsistency of recording "UNCHANGED" status when no actual upgrades have occurred.

## Testing and Usage

### Standard Usage (Recommended)
```bash
# Normal operation with change tracking
ansible-playbook -i inventory/hosts setup.yml

# Status check without recording changes
ansible-playbook -i inventory/hosts setup.yml --tags=matrix-version-summary

# Test in check mode (no actual changes)
ansible-playbook -i inventory/hosts setup.yml --tags=matrix-version-summary --check

# Mixed tag usage (still runs in normal mode)
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,matrix-version-summary
```

## Technical Implementation Details

### Mode Detection
The role uses `ansible_run_tags` to detect execution context:
- **Status Check Mode**: When `ansible_run_tags` contains only `matrix-version-summary`
- **Normal Mode**: All other execution scenarios (including mixed tags)

### Error Handling
The role includes robust error handling for common scenarios:
- Docker command failures (service not running, docker not available)
- Missing or malformed container data
- Fact file access issues
- Invalid retention policy configurations

### Data Safety
In Status Check Mode, the role operates in read-only mode:
- **No file modifications**: Fact files remain unchanged
- **No history updates**: Prevents phantom change records
- **No retention operations**: Skips cleanup that could affect data

### Variable Validation
Key variables are validated during execution:
- Container prefix format validation
- Retention policy value validation
- Execution mode detection verification (when verbose mode enabled)
