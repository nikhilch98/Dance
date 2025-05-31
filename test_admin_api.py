import requests
import json

# Test admin API endpoints
def test_admin_api():
    # Use the admin test user we know exists
    login_data = {
        'mobile_number': '8888888888',  # Known admin user
        'password': 'test123'
    }

    try:
        print("Testing admin API endpoints...")
        
        # Login to get token
        login_response = requests.post('https://nachna.com/api/auth/login', json=login_data)
        print(f'Login status: {login_response.status_code}')
        
        if login_response.status_code == 200:
            auth_data = login_response.json()
            token = auth_data['access_token']
            print(f'Token obtained: {token[:20]}...')
            print(f'User is admin: {auth_data.get("user", {}).get("is_admin", False)}')
            
            # Test config endpoint (this should work)
            config_response = requests.get(
                'https://nachna.com/api/config',
                headers={'Authorization': f'Bearer {token}'}
            )
            print(f'\nConfig endpoint status: {config_response.status_code}')
            if config_response.status_code == 200:
                print(f'Config data: {config_response.json()}')
            else:
                print(f'Config error: {config_response.text}')
            
            # Test admin endpoint (this should now work)
            admin_response = requests.get(
                'https://nachna.com/admin/api/missing_artist_sessions',
                headers={'Authorization': f'Bearer {token}'}
            )
            print(f'\nAdmin endpoint status: {admin_response.status_code}')
            if admin_response.status_code == 200:
                data = admin_response.json()
                print(f'Admin response: Found {len(data)} missing artist sessions')
                if data:
                    print(f'First session: {data[0]}')
            else:
                print(f'Admin error: {admin_response.text}')
            
        else:
            print(f'Login failed: {login_response.text}')
            
    except Exception as e:
        print(f'Error: {e}')

if __name__ == "__main__":
    test_admin_api() 