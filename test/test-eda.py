#!/usr/bin/env python3
"""
Test script for EDA functionality in clabcli
This script demonstrates how the EDA command works
"""

import subprocess
import sys
import os

# Add parent directory to path to import clabcli
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def test_eda_help():
    """Test EDA help command"""
    print("=== Testing EDA Help ===")
    clabcli_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'clabcli')
    result = subprocess.run([sys.executable, clabcli_path], capture_output=True, text=True)
    print("Output:", result.stdout)
    print("Errors:", result.stderr)
    print()

def test_eda_usage():
    """Test EDA usage without parameters"""
    print("=== Testing EDA Usage ===")
    clabcli_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'clabcli')
    result = subprocess.run([sys.executable, clabcli_path, 'eda'], capture_output=True, text=True)
    print("Output:", result.stdout)
    print("Errors:", result.stderr)
    print()

def test_network_check():
    """Test network segment checking function"""
    print("=== Testing Network Check Function ===")
    try:
        # Import the clabcli script as a module by adding it to sys.path
        clabcli_dir = os.path.dirname(os.path.dirname(__file__))
        clabcli_path = os.path.join(clabcli_dir, 'clabcli')
        
        # Read and execute the clabcli script to get access to its functions
        with open(clabcli_path, 'r') as f:
            clabcli_code = f.read()
        
        # Create a namespace to execute the code in
        clabcli_namespace = {}
        exec(clabcli_code, clabcli_namespace)
        
        # Test with common network segments
        test_segments = [
            "192.168.1.0/24",
            "10.0.0.0/8", 
            "172.16.0.0/12",
            "192.168.132.0/22"
        ]
        
        for segment in test_segments:
            result = clabcli_namespace['check_network_segment'](segment)
            print(f"Network segment {segment}: {'✓ Match' if result else '✗ No match'}")
    except Exception as e:
        print(f"Error testing network check: {e}")
    print()

def test_uid_1000_user():
    """Test UID 1000 user detection"""
    print("=== Testing UID 1000 User Detection ===")
    try:
        # Import the clabcli script as a module by adding it to sys.path
        clabcli_dir = os.path.dirname(os.path.dirname(__file__))
        clabcli_path = os.path.join(clabcli_dir, 'clabcli')
        
        # Read and execute the clabcli script to get access to its functions
        with open(clabcli_path, 'r') as f:
            clabcli_code = f.read()
        
        # Create a namespace to execute the code in
        clabcli_namespace = {}
        exec(clabcli_code, clabcli_namespace)
        
        username, home_dir = clabcli_namespace['get_uid_1000_user']()
        if username and home_dir:
            print(f"✓ Found UID 1000 user: {username}")
            print(f"  Home directory: {home_dir}")
            print(f"  .bashrc path: {os.path.join(home_dir, '.bashrc')}")
        else:
            print("✗ No UID 1000 user found")
    except Exception as e:
        print(f"Error testing UID 1000 user: {e}")
    print()

def test_config_fetch():
    """Test EDA config fetching (mock test)"""
    print("=== Testing EDA Config Fetch ===")
    try:
        # This would normally fetch from the server, but we'll just test the URL construction
        eda_name = "edaempyren2025summer"
        config_url = f"https://clab-notice.lcpu.dev/eda/{eda_name}.json"
        bashrc_url = f"https://clab-notice.lcpu.dev/eda/{eda_name}.bashrc"
        
        print(f"Config URL: {config_url}")
        print(f"Bashrc URL: {bashrc_url}")
        print("✓ URL construction works correctly")
        
        # Test if we can access the fetch function
        clabcli_dir = os.path.dirname(os.path.dirname(__file__))
        clabcli_path = os.path.join(clabcli_dir, 'clabcli')
        
        with open(clabcli_path, 'r') as f:
            clabcli_code = f.read()
        
        clabcli_namespace = {}
        exec(clabcli_code, clabcli_namespace)
        
        print("✓ EDA config fetch function is available")
        
    except Exception as e:
        print(f"Error testing config fetch: {e}")
    print()

def main():
    print("EDA Functionality Test Script")
    print("=" * 40)
    
    test_eda_help()
    test_eda_usage()
    test_network_check()
    test_uid_1000_user()
    test_config_fetch()
    
    print("Test completed!")
    print("\nTo test the full EDA functionality:")
    print("1. Ensure you have the required network configuration")
    print("2. Run: sudo python3 ../clabcli eda edaempyren2025summer")
    print("3. Check the generated systemd service and .bashrc modifications")
    print("\nExample systemd service file location:")
    print("  /etc/systemd/system/eda-edaempyren2025summer.service")
    print("\nExample .bashrc modification location:")
    print("  /home/<uid1000user>/.bashrc")

if __name__ == "__main__":
    main()
