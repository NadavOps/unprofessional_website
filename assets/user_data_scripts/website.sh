#!/bin/bash
## changing hostname
hostnamectl set-hostname ${tf_name_prefix}

## Allow SSH
echo "${tf_public_key}" >> /home/ubuntu/.ssh/authorized_keys
echo "${tf_public_key}" >> /root/.ssh/authorized_keys

## Install packages
apt update -y
apt install letsencrypt -y
apt install nginx -y
apt install at -y

## Creates nginx configuration
openssl dhparam -out /etc/nginx/dhparam.pem 2048
cat << 'EOF' > /etc/nginx/snippets/ssl.conf
## taken from: https://www.howtoforge.com/tutorial/nginx-with-letsencrypt-ciphersuite/#on-ubuntu--5
# Specify the TLS versions
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;

# Use this for all devices supports
ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';

# Use the DHPARAM key and ECDH curve >= 256bit
ssl_ecdh_curve secp384r1;
ssl_dhparam /etc/nginx/dhparam.pem;

server_tokens off;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;

# Enable HTTP Strict-Transport-Security
# If you have a subdomain of your site,
# be carefull to use the 'includeSubdomains' options
add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

# Enable OSCP Stapling for Nginx web server
# If you're using the SSL from Letsencrypt,
# use the 'chain.pem' certificate
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/${tf_fqdn}/chain.pem;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# XSS Protection for Nginx web server
add_header X-Frame-Options DENY;
add_header X-XSS-Protection "1; mode=block";
add_header X-Content-Type-Options nosniff;
# add_header X-Robots-Tag none;
EOF

cat << 'EOF' > /etc/nginx/sites-available/default
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	server_name ${tf_fqdn};
	return 301 https://$host$request_uri;
}

server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;

        root   /var/www/html;
        index index.html index.php index.htm;

        server_name ${tf_fqdn};
        error_log /var/log/nginx/error_ssl.log warn;

        ssl_certificate /etc/letsencrypt/live/${tf_fqdn}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${tf_fqdn}/privkey.pem;

        #SSL Configuration
        include snippets/ssl.conf;

        # location ~ /.well-known {
        #         allow all;
        # }


        location / {
            try_files $uri $uri/ =404;
        }


        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }

        location = /robots.txt {
                allow all;
                log_not_found off;
                access_log off;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
                expires max;
                log_not_found off;
        }

}
EOF

## Lets encrypt renewal
cat << 'EOF' > /root/certbot_renewal.sh
#!/bin/bash
certbot renew
while [[ $? != 0 ]]; do
    sleep 3600
    certbot renew
done
bash /root/certbot_expiration_date.sh
EOF

## Lets encrypt check renewal
cat << 'EOF' > /root/certbot_expiration_date.sh
#!/bin/bash
raw_date_output=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/${tf_fqdn}/fullchain.pem)
string_date_output=$(echo $raw_date_output | sed 's/notAfter=//g')
expiry_date_day=$(date --date="$string_date_output" --utc +"%d")
expiry_date_month=$(date --date="$string_date_output" --utc +"%m")
#expiry_date_year=$(date --date="$string_date_output" --utc +"%Y")
echo "0 0 $expiry_date_day $expiry_date_month * bash /root/certbot_renewal.sh" | sudo crontab -
EOF

## Create letsencrypt certificates- will loop until manual DNS change
cat << 'EOF' > /root/initial_certbot_creation.sh
#!/bin/bash
instance_public_ip=$(curl "http://169.254.169.254/latest/meta-data/public-ipv4")
dns_ip=$(dig +short ${tf_fqdn})
while [[ $instance_public_ip != $dns_ip ]]; do
    sleep 60
    dns_ip=$(dig +short ${tf_fqdn})
done
certbot certonly --rsa-key-size 4096 --webroot --agree-tos --no-eff-email --email myemail@gmail.com \
-w /var/www/html -d ${tf_fqdn}
while [[ $? != 0 ]]; do
    sleep 3600
    certbot certonly --rsa-key-size 4096 --webroot --agree-tos --no-eff-email --email myemail@gmail.com \
    -w /var/www/html -d ${tf_fqdn}
done
systemctl reload nginx
bash /root/certbot_expiration_date.sh
EOF
echo "bash /root/initial_certbot_creation.sh" | at now