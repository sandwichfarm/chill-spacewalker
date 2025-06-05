#!/bin/bash

echo "=== VITURE Detection Debug ==="
echo "Time: $(date)"
echo ""

echo "1. USB Device Detection:"
echo "------------------------"
if system_profiler SPUSBDataType | grep -q "VITURE Pro XR"; then
    echo "✓ VITURE USB device found"
    system_profiler SPUSBDataType | grep -A 3 "VITURE Pro XR"
else
    echo "✗ VITURE USB device NOT found"
fi

echo ""
echo "2. Display Detection:"
echo "--------------------"
if system_profiler SPDisplaysDataType | grep -q "VITURE:"; then
    echo "✓ VITURE display found"
    system_profiler SPDisplaysDataType | grep -A 5 "VITURE:"
else
    echo "✗ VITURE display NOT found"
fi

echo ""
echo "3. IOKit Registry Check:"
echo "-----------------------"
if ioreg -r -d0 -c IOUSBDevice | grep -q "35ca"; then
    echo "✓ VITURE found in IOKit USB registry"
else
    echo "✗ VITURE NOT found in IOKit USB registry"
fi

echo ""
echo "4. Display Count:"
echo "----------------"
display_count=$(system_profiler SPDisplaysDataType | grep -c "Resolution:")
echo "Total displays: $display_count"

echo ""
echo "5. CGDisplay API Test:"
echo "---------------------"
# Use a simple Python script to test CoreGraphics
python3 -c "
import subprocess
import sys

# Try to get display count using system_profiler
try:
    result = subprocess.run(['system_profiler', 'SPDisplaysDataType'], 
                          capture_output=True, text=True)
    lines = result.stdout.split('\n')
    viture_found = any('VITURE' in line for line in lines)
    print(f'VITURE in system_profiler: {viture_found}')
except Exception as e:
    print(f'Error: {e}')
" 2>/dev/null || echo "Python test failed"

echo ""
echo "=== End Debug ==="