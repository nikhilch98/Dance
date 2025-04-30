#!/bin/bash

# Check if Go is installed
if ! [ -x "$(command -v go)" ]; then
  echo 'Error: Go is not installed.' >&2
  echo 'Please install Go from https://golang.org/doc/install' >&2
  exit 1
fi

# Install dependencies
echo "Installing dependencies..."
go mod download

# Build the application
echo "Building application..."
go build -o dance_server main.go

# Check if build was successful
if [ $? -eq 0 ]; then
  echo "Build successful!"
  echo "You can run the server with:"
  echo "./dance_server"
  echo "or with specific environment:"
  echo "./dance_server --dev  # For development"
  echo "./dance_server --prod # For production"
else
  echo "Build failed!"
fi

# Make the script executable
chmod +x dance_server

curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/yum.repos.d/ngrok.repo > /dev/null
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-stable-linux-amd64.zip
unzip ngrok-stable-linux-amd64.zip
sudo mv ngrok /usr/local/bin
ngrok config add-authtoken 6jHepSBhYtLuMvFmUUzBZ_3aTpi7kYJTCuTGsVMToiA

sudo dnf install git -y
git clone https://github.com/nikhilch98/Dance.git
cd Dance
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

