#!/usr/bin/env python3
"""
Nachna API Integration Test Runner
=====================================

This script runs the Python API integration tests for the Nachna Flutter app.
It provides various options for running specific test groups and generating reports.

Usage:
    python run_api_tests.py [options]

Options:
    --group [auth|data|reactions|notifications|admin|errors|performance|all]  Run specific test group (default: all)
    --verbose                                                                  Enable verbose output
    --no-cleanup                                                              Don't clean up log files
    --report                                                                   Generate detailed test report
    --base-url URL                                                            Override base URL for testing
    --help                                                                     Show this help message

Examples:
    python run_api_tests.py                           # Run all tests
    python run_api_tests.py --group auth             # Run only authentication tests
    python run_api_tests.py --verbose --report       # Run with verbose output and generate report
    python run_api_tests.py --base-url http://localhost:8000  # Test against local server
"""

import sys
import os
import argparse
import subprocess
import json
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

# ANSI color codes for terminal output
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

class ApiTestRunner:
    """Enhanced test runner for Nachna API integration tests"""
    
    def __init__(self, args):
        self.args = args
        self.test_file = Path(__file__).parent.parent / "test" / "api_integration_test.py"
        self.log_dir = Path(__file__).parent.parent / "test" / "logs"
        self.log_dir.mkdir(exist_ok=True)
        
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = self.log_dir / f"api_tests_{self.timestamp}.log"
        
        # Test groups mapping
        self.test_groups = {
            'auth': 'test_authentication_apis',
            'data': 'test_data_fetching_apis', 
            'reactions': 'test_reaction_apis',
            'notifications': 'test_notification_apis',
            'admin': 'test_admin_apis',
            'errors': 'test_error_handling',
            'performance': 'test_performance'
        }
    
    def print_colored(self, message: str, color: str = Colors.WHITE):
        """Print colored message to console"""
        print(f"{color}{message}{Colors.END}")
    
    def print_header(self, title: str):
        """Print a formatted header"""
        separator = "=" * 70
        self.print_colored(separator, Colors.CYAN)
        self.print_colored(f"  {title}", Colors.BOLD + Colors.CYAN)
        self.print_colored(separator, Colors.CYAN)
    
    def check_connectivity(self) -> bool:
        """Check if the API server is reachable"""
        import requests
        
        base_url = self.args.base_url or 'https://nachna.com'
        
        self.print_colored(f"\n🌐 Checking connectivity to {base_url}...", Colors.YELLOW)
        
        try:
            response = requests.get(f"{base_url}/api/artists?version=v2", timeout=10)
            if response.status_code == 200:
                self.print_colored("✅ Server is reachable", Colors.GREEN)
                return True
            else:
                self.print_colored(f"⚠️ Server responded with status {response.status_code}", Colors.YELLOW)
                return True  # Still continue with tests
        except requests.exceptions.RequestException as e:
            self.print_colored(f"❌ Server is not reachable: {e}", Colors.RED)
            return False
    
    def check_dependencies(self) -> bool:
        """Check if required Python packages are installed"""
        required_packages = ['requests']
        missing_packages = []
        
        for package in required_packages:
            try:
                __import__(package)
            except ImportError:
                missing_packages.append(package)
        
        if missing_packages:
            self.print_colored(f"❌ Missing required packages: {', '.join(missing_packages)}", Colors.RED)
            self.print_colored(f"   Install with: pip install {' '.join(missing_packages)}", Colors.YELLOW)
            return False
        
        return True
    
    def modify_test_config(self) -> str:
        """Create a modified version of the test file with custom configuration"""
        if not self.test_file.exists():
            self.print_colored(f"❌ Test file not found: {self.test_file}", Colors.RED)
            return None
        
        # Read the original test file
        with open(self.test_file, 'r') as f:
            content = f.read()
        
        # Create a temporary modified version
        temp_file = self.test_file.parent / f"api_integration_test_temp_{self.timestamp}.py"
        
        # Modify the content if needed
        if self.args.base_url:
            content = content.replace(
                "base_url: str = 'https://nachna.com'",
                f"base_url: str = '{self.args.base_url}'"
            )
        
        # Write the modified content
        with open(temp_file, 'w') as f:
            f.write(content)
        
        return str(temp_file)
        
    def run_specific_group(self, group: str) -> tuple:
        """Run a specific test group"""
        if group not in self.test_groups:
            self.print_colored(f"❌ Unknown test group: {group}", Colors.RED)
            return False, f"Unknown test group: {group}"
        
        method_name = self.test_groups[group]
        
        # Create a custom test script that runs only the specific group
        base_url_override = f"config.base_url = '{self.args.base_url}'" if self.args.base_url else ""
        
        custom_script = f"""
import sys
sys.path.append('{self.test_file.parent}')

from api_integration_test import ApiTestConfig, ApiTestRunner

def main():
    config = ApiTestConfig()
    {base_url_override}
    
    runner = ApiTestRunner(config)
    
    # Run only the specific test group
    runner.{method_name}()
    
    # Print summary
    total_tests = runner.passed_tests + runner.failed_tests
    success_rate = (runner.passed_tests / total_tests) * 100 if total_tests > 0 else 0
    
    print(f"\\n📊 Group '{group}' Results:")
    print(f"✅ Passed: {{runner.passed_tests}}")
    print(f"❌ Failed: {{runner.failed_tests}}")
    print(f"🎯 Success Rate: {{success_rate:.1f}}%")
    
    return runner.failed_tests == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
"""
        
        temp_script = self.test_file.parent / f"test_group_{group}_{self.timestamp}.py"
        
        try:
            with open(temp_script, 'w') as f:
                f.write(custom_script)
            
            # Run the custom script
            result = subprocess.run([
                sys.executable, str(temp_script)
            ], capture_output=True, text=True, timeout=300)
            
            return result.returncode == 0, result.stdout + result.stderr
            
        finally:
            # Clean up temporary script
            if temp_script.exists():
                temp_script.unlink()
    
    def run_all_tests(self) -> tuple:
        """Run all API integration tests"""
        temp_file = self.modify_test_config()
        
        if not temp_file:
            return False, "Failed to prepare test configuration"
        
        try:
            # Run the test file
            result = subprocess.run([
                sys.executable, temp_file
            ], capture_output=True, text=True, timeout=600)
            
            return result.returncode == 0, result.stdout + result.stderr
            
        finally:
            # Clean up temporary file
            if Path(temp_file).exists():
                Path(temp_file).unlink()
    
    def generate_report(self, output: str):
        """Generate a detailed test report"""
        report_file = self.log_dir / f"test_report_{self.timestamp}.html"
        
        # Parse the output to extract test results
        lines = output.split('\n')
        passed_tests = []
        failed_tests = []
        
        for line in lines:
            if line.startswith('✅'):
                passed_tests.append(line[2:].strip())
            elif line.startswith('❌'):
                failed_tests.append(line[2:].strip())
        
        # Generate HTML report
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Nachna API Test Report - {self.timestamp}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; }}
        .header {{ color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }}
        .summary {{ background: #ecf0f1; padding: 20px; border-radius: 5px; margin: 20px 0; }}
        .success {{ color: #27ae60; }}
        .failure {{ color: #e74c3c; }}
        .test-list {{ margin: 20px 0; }}
        .test-item {{ margin: 5px 0; padding: 5px; border-left: 3px solid #3498db; }}
        .timestamp {{ color: #7f8c8d; }}
    </style>
</head>
<body>
    <h1 class="header">🚀 Nachna API Integration Test Report</h1>
    
    <div class="summary">
        <h2>📊 Test Summary</h2>
        <p><strong>Timestamp:</strong> <span class="timestamp">{datetime.now().isoformat()}</span></p>
        <p><strong>Total Tests:</strong> {len(passed_tests) + len(failed_tests)}</p>
        <p class="success"><strong>Passed:</strong> {len(passed_tests)}</p>
        <p class="failure"><strong>Failed:</strong> {len(failed_tests)}</p>
        <p><strong>Success Rate:</strong> {(len(passed_tests) / (len(passed_tests) + len(failed_tests)) * 100) if (len(passed_tests) + len(failed_tests)) > 0 else 0:.1f}%</p>
    </div>
    
    <div class="test-list">
        <h2 class="success">✅ Passed Tests ({len(passed_tests)})</h2>
        {''.join([f'<div class="test-item">{test}</div>' for test in passed_tests])}
    </div>
    
    <div class="test-list">
        <h2 class="failure">❌ Failed Tests ({len(failed_tests)})</h2>
        {''.join([f'<div class="test-item">{test}</div>' for test in failed_tests])}
    </div>
    
    <div style="margin-top: 40px; border-top: 1px solid #bdc3c7; padding-top: 20px;">
        <h3>📋 Raw Output</h3>
        <pre style="background: #2c3e50; color: #ecf0f1; padding: 20px; border-radius: 5px; overflow-x: auto;">{output}</pre>
    </div>
</body>
</html>
"""
        
        with open(report_file, 'w') as f:
            f.write(html_content)
        
        self.print_colored(f"\n📄 Test report generated: {report_file}", Colors.GREEN)
    
    def cleanup_logs(self):
        """Clean up old log files"""
        if self.args.no_cleanup:
            return
        
        # Keep only the last 10 log files
        log_files = sorted(self.log_dir.glob("*.log"))
        if len(log_files) > 10:
            for old_file in log_files[:-10]:
                old_file.unlink()
                self.print_colored(f"🗑️ Cleaned up old log: {old_file.name}", Colors.YELLOW)
    
    def run(self):
        """Main execution method"""
        self.print_header("NACHNA API INTEGRATION TEST RUNNER")
        
        # Pre-flight checks
        if not self.check_dependencies():
            return 1
        
        if not self.check_connectivity():
            self.print_colored("⚠️ Connectivity check failed, but continuing with tests...", Colors.YELLOW)
        
        # Determine what tests to run
        if self.args.group and self.args.group != 'all':
            self.print_colored(f"\n🎯 Running test group: {self.args.group}", Colors.BLUE)
            success, output = self.run_specific_group(self.args.group)
        else:
            self.print_colored(f"\n🏃 Running all API integration tests", Colors.BLUE)
            success, output = self.run_all_tests()
        
        # Log output to file
        with open(self.log_file, 'w') as f:
            f.write(f"Test run timestamp: {datetime.now().isoformat()}\n")
            f.write(f"Arguments: {vars(self.args)}\n")
            f.write("=" * 70 + "\n")
            f.write(output)
        
        # Display results
        if self.args.verbose:
            print(output)
        else:
            # Show summary only
            lines = output.split('\n')
            for line in lines:
                if any(keyword in line for keyword in ['✅', '❌', '📊', '🎯', '🏁']):
                    print(line)
        
        # Generate report if requested
        if self.args.report:
            self.generate_report(output)
        
        # Display final status
        if success:
            self.print_colored(f"\n🎉 All tests completed successfully!", Colors.GREEN)
            self.print_colored(f"📝 Test log saved to: {self.log_file}", Colors.BLUE)
        else:
            self.print_colored(f"\n💥 Some tests failed!", Colors.RED)
            self.print_colored(f"📝 Check log file for details: {self.log_file}", Colors.YELLOW)
        
        # Cleanup
        self.cleanup_logs()
        
        return 0 if success else 1


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Run Nachna API integration tests",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python run_api_tests.py                           # Run all tests
  python run_api_tests.py --group auth             # Run only authentication tests
  python run_api_tests.py --verbose --report       # Run with verbose output and generate report
  python run_api_tests.py --base-url http://localhost:8000  # Test against local server
        """
    )
    
    parser.add_argument(
        '--group',
        choices=['auth', 'data', 'reactions', 'notifications', 'admin', 'errors', 'performance', 'all'],
        default='all',
        help='Run specific test group (default: all)'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose output'
    )
    
    parser.add_argument(
        '--no-cleanup',
        action='store_true',
        help="Don't clean up old log files"
    )
    
    parser.add_argument(
        '--report',
        action='store_true',
        help='Generate detailed HTML test report'
    )
    
    parser.add_argument(
        '--base-url',
        help='Override base URL for testing (e.g., http://localhost:8000)'
    )
    
    args = parser.parse_args()
    
    # Validate test file exists
    test_file = Path(__file__).parent.parent / "test" / "api_integration_test.py"
    if not test_file.exists():
        print(f"❌ Test file not found: {test_file}")
        print("   Make sure you're running this script from the correct directory")
        return 1
    
    runner = ApiTestRunner(args)
    return runner.run()


if __name__ == "__main__":
    sys.exit(main()) 