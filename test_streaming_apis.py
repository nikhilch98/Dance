#!/usr/bin/env python3
"""
======================================================================
NACHNA APP - STREAMING API TEST SUITE
======================================================================

This file contains comprehensive tests for the streaming APIs:
- POST /api/streaming/refresh-workshops
- GET /api/streaming/process-studio

Testing Approaches:
1. Python SSE Client Testing
2. cURL Command Testing
3. Web Client Testing
4. Performance Testing
5. Error Handling Testing

======================================================================
"""

import requests
import json
import time
import subprocess
import sys
import threading
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
from datetime import datetime
import sseclient
import urllib3

# Disable SSL warnings for testing
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


@dataclass
class StreamingTestConfig:
    """Configuration for streaming API tests"""
    base_url: str = 'http://40.192.39.104:8008'
    studio_id: str = 'dance_n_addiction'
    timeout: int = 30
    max_events: int = 50  # Maximum events to capture per test
    
    # Test parameters
    test_duration: int = 10  # Seconds to run each test
    expected_event_types: List[str] = ['logs', 'progress_bar', 'complete', 'error']


class StreamingEvent:
    """Represents a streaming event"""
    def __init__(self, event_type: str, data: Dict[str, Any], timestamp: datetime):
        self.event_type = event_type
        self.data = data
        self.timestamp = timestamp
    
    def __str__(self):
        return f"[{self.timestamp.strftime('%H:%M:%S')}] {self.event_type}: {json.dumps(self.data, indent=2)}"


class StreamingApiTester:
    """Main tester for streaming APIs"""
    
    def __init__(self, config: StreamingTestConfig):
        self.config = config
        self.session = requests.Session()
        self.session.timeout = config.timeout
        
        # Test results tracking
        self.passed_tests = 0
        self.failed_tests = 0
        self.test_results = []
        self.captured_events = []
    
    def log_test_result(self, test_name: str, success: bool, message: str = "", events: List[StreamingEvent] = None):
        """Log test result with detailed information"""
        status = "✅" if success else "❌"
        result = f"{status} {test_name}"
        if message:
            result += f" - {message}"
        print(result)
        
        if events:
            print(f"   📊 Captured {len(events)} events")
            for event in events[-3:]:  # Show last 3 events
                print(f"   📝 {event}")
        
        self.test_results.append({
            'test': test_name,
            'success': success,
            'message': message,
            'events_count': len(events) if events else 0,
            'timestamp': datetime.now().isoformat()
        })
        
        if success:
            self.passed_tests += 1
        else:
            self.failed_tests += 1
    
    def test_refresh_workshops_streaming(self) -> bool:
        """Test the refresh workshops streaming endpoint"""
        print("\n🔄 Testing Refresh Workshops Streaming...")
        
        try:
            # Prepare request
            url = f"{self.config.base_url}/api/streaming/refresh-workshops"
            headers = {
                'Accept': 'text/event-stream',
                'Cache-Control': 'no-cache',
                'Content-Type': 'application/json'
            }
            data = {
                'studio_id': self.config.studio_id
            }
            
            # Make streaming request
            response = self.session.post(url, json=data, headers=headers, stream=True)
            
            if response.status_code != 200:
                self.log_test_result("Refresh Workshops Streaming", False, f"HTTP {response.status_code}")
                return False
            
            # Parse SSE events
            events = []
            client = sseclient.SSEClient(response)
            
            start_time = time.time()
            for event in client.events():
                if time.time() - start_time > self.config.test_duration:
                    break
                
                try:
                    event_data = json.loads(event.data) if event.data else {}
                    events.append(StreamingEvent(
                        event_type=event.event or 'unknown',
                        data=event_data,
                        timestamp=datetime.now()
                    ))
                    
                    # Check for completion
                    if event.event == 'complete':
                        break
                        
                except json.JSONDecodeError:
                    print(f"   ⚠️  Invalid JSON in event: {event.data}")
                    continue
            
            # Validate events
            if not events:
                self.log_test_result("Refresh Workshops Streaming", False, "No events received")
                return False
            
            # Check for expected event types
            event_types = [e.event_type for e in events]
            has_logs = 'logs' in event_types
            has_progress = 'progress_bar' in event_types
            has_complete = 'complete' in event_types
            
            success = has_logs and has_progress and has_complete
            message = f"Received {len(events)} events (logs: {has_logs}, progress: {has_progress}, complete: {has_complete})"
            
            self.log_test_result("Refresh Workshops Streaming", success, message, events)
            return success
            
        except Exception as e:
            self.log_test_result("Refresh Workshops Streaming", False, str(e))
            return False
    
    def test_process_studio_streaming(self) -> bool:
        """Test the process studio streaming endpoint"""
        print("\n🏢 Testing Process Studio Streaming...")
        
        try:
            # Prepare request
            url = f"{self.config.base_url}/api/streaming/process-studio?studio_id={self.config.studio_id}"
            headers = {
                'Accept': 'text/event-stream',
                'Cache-Control': 'no-cache'
            }
            
            # Make streaming request
            response = self.session.get(url, headers=headers, stream=True)
            
            if response.status_code != 200:
                self.log_test_result("Process Studio Streaming", False, f"HTTP {response.status_code}")
                return False
            
            # Parse SSE events
            events = []
            client = sseclient.SSEClient(response)
            
            start_time = time.time()
            for event in client.events():
                if time.time() - start_time > self.config.test_duration:
                    break
                
                try:
                    event_data = json.loads(event.data) if event.data else {}
                    events.append(StreamingEvent(
                        event_type=event.event or 'unknown',
                        data=event_data,
                        timestamp=datetime.now()
                    ))
                    
                    # Check for completion
                    if event.event == 'complete':
                        break
                        
                except json.JSONDecodeError:
                    print(f"   ⚠️  Invalid JSON in event: {event.data}")
                    continue
            
            # Validate events
            if not events:
                self.log_test_result("Process Studio Streaming", False, "No events received")
                return False
            
            # Check for expected event types
            event_types = [e.event_type for e in events]
            has_logs = 'logs' in event_types
            has_progress = 'progress_bar' in event_types
            has_complete = 'complete' in event_types
            
            success = has_logs and has_progress and has_complete
            message = f"Received {len(events)} events (logs: {has_logs}, progress: {has_progress}, complete: {has_complete})"
            
            self.log_test_result("Process Studio Streaming", success, message, events)
            return success
            
        except Exception as e:
            self.log_test_result("Process Studio Streaming", False, str(e))
            return False
    
    def test_error_handling(self) -> bool:
        """Test error handling scenarios"""
        print("\n🚨 Testing Error Handling...")
        
        # Test 1: Invalid studio ID
        try:
            url = f"{self.config.base_url}/api/streaming/process-studio?studio_id=invalid_studio"
            headers = {'Accept': 'text/event-stream'}
            
            response = self.session.get(url, headers=headers, stream=True)
            
            if response.status_code == 200:
                # Should receive error event
                client = sseclient.SSEClient(response)
                events = []
                
                for event in client.events():
                    events.append(StreamingEvent(
                        event_type=event.event or 'unknown',
                        data=json.loads(event.data) if event.data else {},
                        timestamp=datetime.now()
                    ))
                    break  # Just check first event
                
                has_error = any(e.event_type == 'error' for e in events)
                self.log_test_result("Error Handling - Invalid Studio ID", has_error, 
                                   f"Received {len(events)} events", events)
            else:
                self.log_test_result("Error Handling - Invalid Studio ID", True, 
                                   f"Expected error response: {response.status_code}")
                
        except Exception as e:
            self.log_test_result("Error Handling - Invalid Studio ID", False, str(e))
        
        # Test 2: Missing studio ID
        try:
            url = f"{self.config.base_url}/api/streaming/process-studio"
            headers = {'Accept': 'text/event-stream'}
            
            response = self.session.get(url, headers=headers, stream=True)
            
            if response.status_code == 200:
                client = sseclient.SSEClient(response)
                events = []
                
                for event in client.events():
                    events.append(StreamingEvent(
                        event_type=event.event or 'unknown',
                        data=json.loads(event.data) if event.data else {},
                        timestamp=datetime.now()
                    ))
                    break
                
                has_error = any(e.event_type == 'error' for e in events)
                self.log_test_result("Error Handling - Missing Studio ID", has_error, 
                                   f"Received {len(events)} events", events)
            else:
                self.log_test_result("Error Handling - Missing Studio ID", True, 
                                   f"Expected error response: {response.status_code}")
                
        except Exception as e:
            self.log_test_result("Error Handling - Missing Studio ID", False, str(e))
        
        return True
    
    def test_performance(self) -> bool:
        """Test performance characteristics"""
        print("\n⚡ Testing Performance...")
        
        # Test response time
        start_time = time.time()
        try:
            url = f"{self.config.base_url}/api/streaming/process-studio?studio_id={self.config.studio_id}"
            headers = {'Accept': 'text/event-stream'}
            
            response = self.session.get(url, headers=headers, stream=True)
            first_event_time = time.time()
            
            if response.status_code == 200:
                client = sseclient.SSEClient(response)
                events = []
                
                for event in client.events():
                    events.append(StreamingEvent(
                        event_type=event.event or 'unknown',
                        data=json.loads(event.data) if event.data else {},
                        timestamp=datetime.now()
                    ))
                    
                    if len(events) >= 5:  # Get first 5 events
                        break
                
                response_time = first_event_time - start_time
                events_per_second = len(events) / (time.time() - start_time)
                
                success = response_time < 5.0 and events_per_second > 0.5
                message = f"Response time: {response_time:.2f}s, Events/sec: {events_per_second:.2f}"
                
                self.log_test_result("Performance - Response Time", success, message, events)
                return success
            else:
                self.log_test_result("Performance - Response Time", False, f"HTTP {response.status_code}")
                return False
                
        except Exception as e:
            self.log_test_result("Performance - Response Time", False, str(e))
            return False
    
    def generate_curl_commands(self):
        """Generate cURL commands for manual testing"""
        print("\n📋 cURL Commands for Manual Testing:")
        print("=" * 50)
        
        # Refresh Workshops
        print("\n🔄 Refresh Workshops Streaming:")
        print(f"""curl -N -H "Accept: text/event-stream" \\
     -H "Cache-Control: no-cache" \\
     -H "Content-Type: application/json" \\
     -X POST \\
     -d '{{"studio_id":"{self.config.studio_id}"}}' \\
     "{self.config.base_url}/api/streaming/refresh-workshops"
""")
        
        # Process Studio
        print("\n🏢 Process Studio Streaming:")
        print(f"""curl -N -H "Accept: text/event-stream" \\
     -H "Cache-Control: no-cache" \\
     -X GET \\
     "{self.config.base_url}/api/streaming/process-studio?studio_id={self.config.studio_id}"
""")
        
        # Error test
        print("\n🚨 Error Test (Invalid Studio):")
        print(f"""curl -N -H "Accept: text/event-stream" \\
     -H "Cache-Control: no-cache" \\
     -X GET \\
     "{self.config.base_url}/api/streaming/process-studio?studio_id=invalid_studio"
""")
    
    def generate_web_client_code(self):
        """Generate JavaScript code for web client testing"""
        print("\n🌐 JavaScript Web Client Code:")
        print("=" * 50)
        
        print("""
// HTML Test Client for Streaming APIs
<!DOCTYPE html>
<html>
<head>
    <title>Streaming API Test Client</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .container { max-width: 800px; margin: 0 auto; }
        .button { padding: 10px 20px; margin: 10px; background: #007bff; color: white; border: none; cursor: pointer; }
        .button:hover { background: #0056b3; }
        .log { background: #f8f9fa; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .progress { width: 100%; height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; }
        .progress-bar { height: 100%; background: #28a745; transition: width 0.3s; }
        .event-log { max-height: 400px; overflow-y: auto; border: 1px solid #ddd; padding: 10px; }
        .event { margin: 5px 0; padding: 5px; border-left: 3px solid #007bff; }
        .event.error { border-left-color: #dc3545; }
        .event.success { border-left-color: #28a745; }
        .event.warning { border-left-color: #ffc107; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Streaming API Test Client</h1>
        
        <div>
            <button class="button" onclick="testRefreshWorkshops()">Test Refresh Workshops</button>
            <button class="button" onclick="testProcessStudio()">Test Process Studio</button>
            <button class="button" onclick="clearLog()">Clear Log</button>
        </div>
        
        <div class="progress">
            <div class="progress-bar" id="progressBar" style="width: 0%"></div>
        </div>
        
        <div class="event-log" id="eventLog"></div>
    </div>

    <script>
        let eventSource = null;
        
        function addEvent(message, type = 'info') {
            const log = document.getElementById('eventLog');
            const event = document.createElement('div');
            event.className = `event ${type}`;
            event.innerHTML = `<strong>[${new Date().toLocaleTimeString()}]</strong> ${message}`;
            log.appendChild(event);
            log.scrollTop = log.scrollHeight;
        }
        
        function updateProgress(percentage) {
            document.getElementById('progressBar').style.width = percentage + '%';
        }
        
        function clearLog() {
            document.getElementById('eventLog').innerHTML = '';
            updateProgress(0);
        }
        
        function closeConnection() {
            if (eventSource) {
                eventSource.close();
                eventSource = null;
            }
        }
        
        function testRefreshWorkshops() {
            closeConnection();
            clearLog();
            addEvent('Starting Refresh Workshops test...', 'info');
            
            const requestData = {
                studio_id: '""" + self.config.studio_id + """'
            };
            
            // Note: EventSource doesn't support POST with body, so we'll use fetch
            fetch('""" + self.config.base_url + """/api/streaming/refresh-workshops', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'text/event-stream',
                    'Cache-Control': 'no-cache'
                },
                body: JSON.stringify(requestData)
            }).then(response => {
                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                
                function readStream() {
                    reader.read().then(({done, value}) => {
                        if (done) {
                            addEvent('Stream completed', 'success');
                            return;
                        }
                        
                        const chunk = decoder.decode(value);
                        const lines = chunk.split('\\n');
                        
                        lines.forEach(line => {
                            if (line.startsWith('event: ')) {
                                const eventType = line.substring(7);
                                // Handle different event types
                                if (eventType === 'progress_bar') {
                                    // Parse progress data
                                    addEvent('Progress update received', 'info');
                                } else if (eventType === 'logs') {
                                    addEvent('Log message received', 'info');
                                } else if (eventType === 'complete') {
                                    addEvent('Process completed', 'success');
                                }
                            }
                        });
                        
                        readStream();
                    });
                }
                
                readStream();
            }).catch(error => {
                addEvent('Error: ' + error.message, 'error');
            });
        }
        
        function testProcessStudio() {
            closeConnection();
            clearLog();
            addEvent('Starting Process Studio test...', 'info');
            
            eventSource = new EventSource('""" + self.config.base_url + """/api/streaming/process-studio?studio_id=""" + self.config.studio_id + """');
            
            eventSource.onopen = function() {
                addEvent('Connection established', 'success');
            };
            
            eventSource.addEventListener('logs', function(event) {
                const data = JSON.parse(event.data);
                addEvent(`[${data.data.level}] ${data.data.message}`, data.data.level);
            });
            
            eventSource.addEventListener('progress_bar', function(event) {
                const data = JSON.parse(event.data);
                updateProgress(data.data.percentage);
                addEvent(`Progress: ${data.data.percentage}% (${data.data.current}/${data.data.total})`, 'info');
            });
            
            eventSource.addEventListener('complete', function(event) {
                addEvent('Process completed successfully!', 'success');
                eventSource.close();
            });
            
            eventSource.addEventListener('error', function(event) {
                const data = JSON.parse(event.data);
                addEvent(`Error: ${data.error}`, 'error');
            });
            
            eventSource.onerror = function(event) {
                addEvent('Connection error occurred', 'error');
            };
        }
    </script>
</body>
</html>
""")
    
    def run_all_tests(self):
        """Run all streaming API tests"""
        print("🚀 Starting Streaming API Test Suite")
        print("=" * 50)
        print(f"Base URL: {self.config.base_url}")
        print(f"Studio ID: {self.config.studio_id}")
        print(f"Test Duration: {self.config.test_duration} seconds")
        print("=" * 50)
        
        # Run tests
        self.test_refresh_workshops_streaming()
        self.test_process_studio_streaming()
        self.test_error_handling()
        self.test_performance()
        
        # Generate testing resources
        self.generate_curl_commands()
        self.generate_web_client_code()
        
        # Print summary
        self.print_test_summary()
    
    def print_test_summary(self):
        """Print test results summary"""
        print("\n" + "=" * 50)
        print("📊 TEST SUMMARY")
        print("=" * 50)
        print(f"✅ Passed: {self.passed_tests}")
        print(f"❌ Failed: {self.failed_tests}")
        print(f"📈 Success Rate: {(self.passed_tests / (self.passed_tests + self.failed_tests) * 100):.1f}%")
        
        print("\n📋 Detailed Results:")
        for result in self.test_results:
            status = "✅" if result['success'] else "❌"
            print(f"{status} {result['test']} - {result['message']}")
        
        print("\n🎯 Next Steps:")
        print("1. Use the cURL commands above for manual testing")
        print("2. Save the HTML code to test_streaming_web_client.html")
        print("3. Open the HTML file in your browser for interactive testing")
        print("4. Monitor the server logs for any issues")


def main():
    """Main function to run streaming API tests"""
    config = StreamingTestConfig()
    
    # Allow command line overrides
    if len(sys.argv) > 1:
        config.base_url = sys.argv[1]
    if len(sys.argv) > 2:
        config.studio_id = sys.argv[2]
    
    tester = StreamingApiTester(config)
    tester.run_all_tests()


if __name__ == "__main__":
    main() 