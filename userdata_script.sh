#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
 echo 'Hooray The Test Page Is Working :)' | sudo tee -a /var/www/html/index.html
