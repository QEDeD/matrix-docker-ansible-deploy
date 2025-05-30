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

- `matrix_history_max_entries`: Maximum number of history entries to keep (default: 100). Set to 0 for unlimited.
- `matrix_history_retention_days`: Number of days to retain history entries (default: 365). Set to 0 for unlimited.
- `matrix_show_version_summary`: Enable/disable version summary display (default: true)
- `matrix_container_prefix`: Container name prefix to filter for Matrix containers (default: "matrix-")
- `matrix_table_style_unicode`: Use Unicode characters for table borders (default: true)

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
