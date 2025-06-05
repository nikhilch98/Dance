# Nachna API Integration Tests (Python)

This directory contains comprehensive integration tests for all APIs used in the Nachna Flutter app, written in Python for direct API testing.

## 📁 Files

- `../api_integration_test.py` - Main Python test suite with all API test cases
- `../../scripts/run_api_tests.py` - Enhanced Python test runner with reporting capabilities
- `README.md` - This documentation file

## 🚀 Quick Start

### Prerequisites

Make sure you have Python 3.7+ and the required packages:

```bash
pip install requests
```

### Running Tests

```bash
# Run all tests
cd nachna
python scripts/run_api_tests.py

# Run specific test group
python scripts/run_api_tests.py --group auth

# Run with verbose output and generate report
python scripts/run_api_tests.py --verbose --report

# Test against local development server
python scripts/run_api_tests.py --base-url http://localhost:8000
```

## 📊 Test Coverage

The test suite covers all HTTP endpoints used by the Flutter app:

### Authentication APIs
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/auth/profile` - Get user profile
- `POST /api/auth/config` - Get app config with device token sync
- `PUT /api/auth/profile` - Update user profile
- `PUT /api/auth/password` - Change password
- `POST /api/auth/profile-picture` - Upload profile picture
- `DELETE /api/auth/profile-picture` - Remove profile picture
- `DELETE /api/auth/account` - Delete account

### Data Fetching APIs
- `GET /api/artists?version=v2` - Fetch all artists
- `GET /api/artists?version=v2&has_workshops=true` - Fetch artists with workshops
- `GET /api/studios?version=v2` - Fetch all studios
- `GET /api/workshops?version=v2` - Fetch all workshops
- `GET /api/workshops_by_artist/{artistId}?version=v2` - Fetch workshops by artist
- `GET /api/workshops_by_studio/{studioId}?version=v2` - Fetch workshops by studio
- `GET /api/config` - Fetch app configuration

### Reaction APIs
- `POST /api/reactions` - Create reaction (like/follow)
- `DELETE /api/reactions` - Remove reaction
- `GET /api/user/reactions` - Get user's reactions
- `GET /api/reactions/stats/{entityType}/{entityId}` - Get reaction statistics

### Notification APIs
- `POST /api/notifications/register-token` - Register device token
- `GET /api/notifications/device-token` - Get current device token
- `DELETE /api/notifications/unregister-token` - Unregister device token

### Admin APIs
- `GET /admin/api/missing_artist_sessions` - Get workshops missing artists
- `GET /admin/api/missing_song_sessions` - Get workshops missing songs
- `PUT /admin/api/workshops/{uuid}/assign_artist` - Assign artist to workshop
- `PUT /admin/api/workshops/{uuid}/assign_song` - Assign song to workshop
- `POST /admin/api/send-test-notification` - Send test notification
- `POST /admin/api/test-apns` - Test APNs functionality

## 🎯 Test Groups

You can run specific test groups:

- `auth` - Authentication-related tests
- `data` - Data fetching tests
- `reactions` - Reaction system tests
- `notifications` - Notification system tests
- `admin` - Admin functionality tests
- `errors` - Error handling tests
- `performance` - Performance validation tests
- `all` - Run all test groups (default)

## 🔧 Test Runner Options

```bash
python scripts/run_api_tests.py [options]

Options:
  --group [auth|data|reactions|notifications|admin|errors|performance|all]
          Run specific test group (default: all)
  --verbose, -v
          Enable verbose output showing all test details
  --no-cleanup
          Don't clean up old log files (keeps all historical logs)
  --report
          Generate detailed HTML test report
  --base-url URL
          Override base URL for testing (useful for local development)
  --help
          Show help message
```

## 📋 Test Configuration

The test configuration is defined in `ApiTestConfig` class:

```python
@dataclass
class ApiTestConfig:
    base_url: str = 'https://nachna.com'           # API base URL
    test_mobile_number: str = '9999999999'         # Test user mobile
    test_password: str = 'test123'                 # Test user password
    test_user_id: str = '683cdbb39caf05c68764cde4' # Test user ID
    timeout: int = 30                              # Request timeout
    
    # Test data IDs (update with real IDs from your database)
    test_artist_id: str = 'test_artist_id'
    test_studio_id: str = 'test_studio_id'
    test_workshop_uuid: str = 'test_workshop_uuid'
    test_device_token: str = 'test_device_token_for_integration_testing'
```

## 📈 Test Output

The tests provide colored console output with emoji indicators:

- ✅ **Passed Test** - Test completed successfully
- ❌ **Failed Test** - Test failed with error details
- 🔐 **Auth Tests** - Authentication test group
- 📊 **Data Tests** - Data fetching test group
- ❤️ **Reaction Tests** - Reaction system test group
- 🔔 **Notification Tests** - Notification test group
- 👑 **Admin Tests** - Admin functionality test group
- 🚨 **Error Tests** - Error handling test group
- ⚡ **Performance Tests** - Performance validation test group

## 📄 Test Reports

When using the `--report` flag, the test runner generates an HTML report with:

- Test summary with success/failure counts
- Detailed list of passed and failed tests
- Raw test output for debugging
- Timestamp and configuration details

Reports are saved to `test/logs/test_report_YYYYMMDD_HHMMSS.html`.

## 🔍 Logs

Test logs are automatically saved to `test/logs/api_tests_YYYYMMDD_HHMMSS.log` with:

- Test execution timestamp
- Command-line arguments used
- Complete test output
- Error details for failed tests

## 🛠️ Troubleshooting

### Common Issues

1. **Connection Refused**
   ```
   ❌ Server is not reachable: Connection refused
   ```
   - Check if the API server is running
   - Verify the base URL is correct
   - Check network connectivity

2. **Authentication Failed**
   ```
   ❌ POST /api/auth/login - 401 Unauthorized
   ```
   - Verify test credentials are correct
   - Check if test user exists in database
   - Ensure user account is not locked

3. **Missing Dependencies**
   ```
   ❌ Missing required packages: requests
   ```
   - Install required packages: `pip install requests`

4. **Test File Not Found**
   ```
   ❌ Test file not found
   ```
   - Ensure you're running from the correct directory
   - Check that `test/api_integration_test.py` exists

### Debug Mode

For detailed debugging, use verbose output:

```bash
python scripts/run_api_tests.py --verbose --group auth
```

This shows:
- Full HTTP request/response details
- Detailed error messages
- Test execution timing
- Configuration values

## 🔄 Continuous Integration

To use these tests in CI/CD pipelines:

```bash
# Basic test run with exit code
python scripts/run_api_tests.py

# Generate report for CI artifacts
python scripts/run_api_tests.py --report --no-cleanup

# Test specific functionality
python scripts/run_api_tests.py --group auth --group data
```

The test runner returns appropriate exit codes:
- `0` - All tests passed
- `1` - Some tests failed or error occurred

## 📚 Adding New Tests

When adding new API endpoints to the Flutter app, follow these steps:

1. **Add the API call** to the appropriate Flutter service file
2. **Add test case** to `test/api_integration_test.py`:
   ```python
   try:
       response = self.make_request('POST', '/api/new/endpoint', {
           'param1': 'value1',
           'param2': 'value2'
       }, auth_required=True)
       
       assert response.status_code == 200
       data = response.json()
       assert 'expected_field' in data
       
       self.log_test_result("POST /api/new/endpoint", True, "Success message")
   except Exception as e:
       self.log_test_result("POST /api/new/endpoint", False, str(e))
   ```

3. **Update documentation** in this README and the test file header
4. **Test the new endpoint** by running the appropriate test group

## 🔐 Security

- Test credentials are for development/testing only
- Production APIs should not be tested with these scripts
- Sensitive data is not logged in test outputs
- Use environment variables for different test environments

## ⚡ Performance

The test suite includes performance validation:

- Response time monitoring (< 5 seconds expected)
- Concurrent request handling
- Memory usage validation
- Network timeout handling

Performance results are included in test reports and can help identify API bottlenecks.

---

## 📞 Support

If you encounter issues with the API integration tests:

1. Check the troubleshooting section above
2. Review test logs in `test/logs/`
3. Run tests in verbose mode for detailed output
4. Verify API server status and connectivity

For questions about specific test failures, include the test log output and any error messages. 