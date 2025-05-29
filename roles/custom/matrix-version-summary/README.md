# Matrix Version Summary and History

This role tracks container version changes over time and provides tools to view and manage the version history.

## Features

- Records version changes of Matrix containers during playbook runs
- Maintains a history of changes with timestamps and users
- Displays version changes in a clean, formatted table
- Provides full history view for each service
- Supports filtering by service name
- Includes tools to manage history (clear, trim)

## Usage

### View Version History

```bash
# View changes history (default mode)
ansible-playbook -i inventory/hosts roles/custom/matrix-version-summary/tasks/history_playbook.yml -e "target_host=your-matrix-server.com" -K

# View full service history
ansible-playbook -i inventory/hosts roles/custom/matrix-version-summary/tasks/history_playbook.yml -e "target_host=your-matrix-server.com view_mode=full" -K

# Filter for a specific service
ansible-playbook -i inventory/hosts roles/custom/matrix-version-summary/tasks/history_playbook.yml -e "target_host=your-matrix-server.com service_filter=matrix-synapse" -K
