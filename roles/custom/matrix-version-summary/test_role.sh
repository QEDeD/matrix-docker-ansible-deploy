#!/bin/bash
# Test script to verify the Matrix Version Summary role functionality

echo "=== Matrix Version Summary Role Test ==="
echo

# Test 1: Basic role syntax check
echo "1. Testing role syntax..."
cd /home/ansible-admin/matrix-docker-ansible-deploy/roles/custom/matrix-version-summary
if ansible-playbook --syntax-check test_role_syntax.yml > /dev/null 2>&1; then
    echo "   ✓ Role syntax is valid"
else
    echo "   ✗ Role syntax has errors"
    exit 1
fi

# Test 2: Check all YAML files for validity
echo "2. Testing YAML file validity..."
cd /home/ansible-admin/matrix-docker-ansible-deploy/roles/custom/matrix-version-summary/tasks
yaml_valid=true
for file in *.yml; do
    if python3 -c "import yaml; yaml.safe_load(open('$file', 'r').read())" > /dev/null 2>&1; then
        echo "   ✓ $file is valid"
    else
        echo "   ✗ $file has YAML errors"
        yaml_valid=false
    fi
done

if [ "$yaml_valid" = false ]; then
    exit 1
fi

# Test 3: Check for unsupported repeat filters
echo "3. Checking for unsupported 'repeat' filters..."
cd /home/ansible-admin/matrix-docker-ansible-deploy/roles/custom/matrix-version-summary
if grep -r "repeat(" tasks/ > /dev/null 2>&1; then
    echo "   ✗ Found unsupported 'repeat' filters:"
    grep -rn "repeat(" tasks/
    exit 1
else
    echo "   ✓ No unsupported 'repeat' filters found"
fi

# Test 4: Verify role structure
echo "4. Checking role structure..."
required_files=(
    "tasks/main.yml"
    "tasks/display_summary.yml"
    "tasks/view_history.yml"
    "tasks/view_service_history.yml"
    "defaults/main.yml"
    "README.md"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ $file exists"
    else
        echo "   ✗ $file is missing"
        exit 1
    fi
done

echo
echo "=== All tests passed! The Matrix Version Summary role is ready for use. ==="
echo
echo "Usage examples:"
echo "  # Run with version summary display"
echo "  ansible-playbook site.yml --tags matrix-version-summary"
echo
echo "  # View version history"
echo "  ansible-playbook playbooks/matrix-version-summary/history_playbook.yml -e view_mode=changes"
echo
echo "  # View full service history"
echo "  ansible-playbook playbooks/matrix-version-summary/history_playbook.yml -e view_mode=full"
echo
