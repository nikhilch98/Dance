

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

