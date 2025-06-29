#!/usr/bin/env python3
"""
Deployment helper for Nachna Workshop MCP server
Helps deploy the server to make it accessible to OpenAI and other platforms
"""

import subprocess
import sys
import requests
import time
from pathlib import Path


def check_requirements():
    """Check if required tools are available"""
    tools = {
        "git": "git --version",
        "python": "python --version"
    }
    
    missing = []
    for tool, cmd in tools.items():
        try:
            subprocess.run(cmd.split(), capture_output=True, check=True)
            print(f"✅ {tool} is available")
        except (subprocess.CalledProcessError, FileNotFoundError):
            missing.append(tool)
            print(f"❌ {tool} is not available")
    
    if missing:
        print(f"\n❌ Missing required tools: {', '.join(missing)}")
        return False
    
    return True


def test_local_server():
    """Test if the local MCP server is working"""
    try:
        response = requests.get("http://localhost:8002/mcp/server-info", timeout=5)
        if response.status_code == 200:
            print("✅ Local MCP server is working")
            return True
        else:
            print(f"❌ Local server error: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Cannot connect to local server: {e}")
        return False


def deploy_to_railway():
    """Deploy to Railway (free tier available)"""
    print("\n🚄 Deploying to Railway...")
    print("1. Install Railway CLI:")
    print("   npm install -g @railway/cli")
    print()
    print("2. Login to Railway:")
    print("   railway login")
    print()
    print("3. Create a new project:")
    print("   railway init")
    print()
    print("4. Deploy:")
    print("   railway up")
    print()
    print("5. Get your deployment URL:")
    print("   railway domain")
    print()
    print("🔗 Railway provides HTTPS URLs that work with OpenAI MCP")


def deploy_to_render():
    """Deploy to Render (free tier available)"""
    print("\n🎨 Deploying to Render...")
    print("1. Create a new Web Service on https://render.com")
    print("2. Connect your GitHub repository")
    print("3. Use these settings:")
    print("   - Environment: Python 3")
    print("   - Build Command: pip install -r requirements.txt")
    print("   - Start Command: uvicorn app.main:app --host 0.0.0.0 --port $PORT")
    print("4. Deploy and get your HTTPS URL")
    print()
    print("🔗 Render provides HTTPS URLs that work with OpenAI MCP")


def deploy_to_heroku():
    """Deploy to Heroku"""
    print("\n🔥 Deploying to Heroku...")
    print("1. Install Heroku CLI from https://devcenter.heroku.com/articles/heroku-cli")
    print("2. Login:")
    print("   heroku login")
    print("3. Create app:")
    print("   heroku create nachna-mcp-server")
    print("4. Deploy:")
    print("   git push heroku main")
    print("5. Get URL:")
    print("   heroku info")
    print()
    print("🔗 Heroku provides HTTPS URLs that work with OpenAI MCP")


def create_procfile():
    """Create Procfile for deployment"""
    procfile_content = "web: uvicorn app.main:app --host 0.0.0.0 --port $PORT\n"
    
    with open("Procfile", "w") as f:
        f.write(procfile_content)
    
    print("✅ Created Procfile for deployment")


def create_requirements_txt():
    """Create requirements.txt if it doesn't exist"""
    if Path("requirements.txt").exists():
        print("✅ requirements.txt already exists")
        return
    
    requirements = [
        "fastapi>=0.104.0",
        "uvicorn[standard]>=0.24.0",
        "pydantic>=2.4.0",
        "pymongo>=4.5.0",
        "requests>=2.31.0",
        "python-multipart>=0.0.6",
        "aiofiles>=23.0.0",
        "Jinja2>=3.1.0",
    ]
    
    with open("requirements.txt", "w") as f:
        f.write("\n".join(requirements))
    
    print("✅ Created requirements.txt")


def setup_ngrok():
    """Set up ngrok for quick public URL (temporary)"""
    print("\n🌐 Setting up ngrok for temporary public access...")
    print("1. Download ngrok from https://ngrok.com/download")
    print("2. Sign up for free account at https://ngrok.com/signup")
    print("3. Get your authtoken from https://dashboard.ngrok.com/get-started/your-authtoken")
    print("4. Configure ngrok:")
    print("   ngrok config add-authtoken YOUR_AUTHTOKEN")
    print("5. Start your server:")
    print("   uvicorn app.main:app --reload --port 8002")
    print("6. In another terminal, expose it:")
    print("   ngrok http 8002")
    print("7. Use the HTTPS URL from ngrok in your OpenAI code")
    print()
    print("⚠️  Note: ngrok URLs are temporary and will change when restarted")


def update_openai_script(deployment_url):
    """Update the test script with deployment URL"""
    test_file = Path("test_random.py")
    if test_file.exists():
        content = test_file.read_text()
        updated_content = content.replace(
            'server_url = "http://localhost:8002/mcp"',
            f'server_url = "{deployment_url}"'
        )
        test_file.write_text(updated_content)
        print(f"✅ Updated test_random.py with deployment URL: {deployment_url}")


def main():
    """Main deployment workflow"""
    print("🚀 Nachna Workshop MCP Server Deployment Helper")
    print("=" * 60)
    
    if not check_requirements():
        sys.exit(1)
    
    print(f"\n🔍 Testing local server...")
    if not test_local_server():
        print("❌ Please start your local server first:")
        print("   uvicorn app.main:app --reload --port 8002")
        print("Then run this script again.")
        return
    
    print("\n📦 Preparing deployment files...")
    create_procfile()
    create_requirements_txt()
    
    print("\n🌐 Deployment Options:")
    print("=" * 40)
    print("1. Railway (Recommended - Free tier with HTTPS)")
    print("2. Render (Free tier with HTTPS)")
    print("3. Heroku (Free tier discontinued, but still popular)")
    print("4. ngrok (Quick temporary solution)")
    print("5. Manual instructions")
    
    try:
        choice = input("\nChoose deployment option (1-5): ").strip()
        
        if choice == "1":
            deploy_to_railway()
        elif choice == "2":
            deploy_to_render()
        elif choice == "3":
            deploy_to_heroku()
        elif choice == "4":
            setup_ngrok()
        elif choice == "5":
            print("\n📋 Manual Deployment Instructions:")
            print("1. Deploy your FastAPI app to any cloud provider")
            print("2. Ensure it's accessible via HTTPS")
            print("3. Update your OpenAI code with the deployment URL")
            print("4. Test with: python test_random.py")
        else:
            print("❌ Invalid choice")
            return
            
        print("\n" + "=" * 60)
        print("🎉 Next Steps:")
        print("1. Deploy using the chosen method above")
        print("2. Get your HTTPS deployment URL")
        print("3. Update test_random.py with your deployment URL")
        print("4. Test OpenAI integration: python test_random.py")
        print()
        print("💡 Remember: OpenAI MCP requires HTTPS URLs (not HTTP)")
        
    except KeyboardInterrupt:
        print("\n\n👋 Deployment cancelled")


if __name__ == "__main__":
    main() 