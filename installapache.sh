#! /bin/bash
sudo apt-get update
sudo apt-get install apache2 -y
sudo systemctl start apache2
sudo systemctl enable apache2
echo "Hi from $(hostname)" > /var/www/html/index.html
