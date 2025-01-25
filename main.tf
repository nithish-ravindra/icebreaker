resource "aws_instance" "ec2_instance" {
  ami           = "ami-043a5a82b6cf98947"  # Amazon linux 
  instance_type = "t2.micro"            

  tags = {
    Name = "icebreaker-test-${var.env}"
  }

  # subnet_id = "subnet-038e631b27fcebfd3"
  security_groups = [aws_security_group.ec2_sg.name]


  user_data = <<-EOF
    #!/bin/bash
    set -x
    yum update -y

    # Install Docker
    amazon-linux-extras install docker -y
    service docker start
    systemctl enable docker
    usermod -a -G docker ec2-user
    chmod 666 /var/run/docker.sock

    # Install Docker Compose
    curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Create directories for Docker Compose and nginx config
    mkdir -p /home/ec2-user/app
    mkdir -p /home/ec2-user/app/nginx
    
    cat > /home/ec2-user/app/conf.json <<EOF_JSON_CONF
    {
      "db_connection": "host=product-db port=5432 user=postgres password=password dbname=products sslmode=disable",
      "bind_address": ":9090",
      "metrics_address": ":9103"
    }
    EOF_JSON_CONF


    # Upload nginx.conf
    cat > /home/ec2-user/app/nginx/nginx.conf <<EOF_NGINX_CONF
      proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=STATIC:10m inactive=7d use_temp_path=off;

      upstream frontend_upstream {
        server frontend:3000;
      }

      server {
        listen 80;
        server_name  localhost;

        server_tokens off;

        gzip on;
        gzip_proxied any;
        gzip_comp_level 4;
        gzip_types text/css application/javascript image/svg+xml;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;

        location /_next/static {
          proxy_cache STATIC;
          proxy_pass http://frontend_upstream;

          # For testing cache - remove before deploying to production
          add_header X-Cache-Status $upstream_cache_status;
        }

        location /static {
          proxy_cache STATIC;
          proxy_ignore_headers Cache-Control;
          proxy_cache_valid 60m;
          proxy_pass http://frontend_upstream;

          # For testing cache - remove before deploying to production
          add_header X-Cache-Status $upstream_cache_status;
        }

        location / {
          proxy_pass http://frontend_upstream;
        }

        location /api {
          proxy_pass http://public-api:8080;
        }
      }
    EOF_NGINX_CONF

    # Upload your docker-compose.yml and nginx.conf
    cat > /home/ec2-user/app/docker-compose.yml <<EOF_DOCKER_COMPOSE
      version: '3.8'
      services:
        frontend:
          image: 'hashicorpdemoapp/frontend:v1.0.3'
          environment:
            - NEXT_PUBLIC_PUBLIC_API_URL=http://localhost
        nginx:
          image: nginx:alpine
          links:
            - 'public-api:public-api'
          volumes:
            - type: bind
              source: ./nginx.conf
              target: /etc/nginx/conf.d/default.conf
          ports:
            - 80:80
        public-api:
          image: 'hashicorpdemoapp/public-api:v0.0.6'
          environment:
            - PRODUCT_API_URI=http://product-api:9090
            - PAYMENT_API_URI=http://payments:8080
          links:
            - 'product-api:product-api'
            - 'payments:payments'
          ports:
            - '8080:8080'
        product-api:
          image: 'hashicorpdemoapp/product-api:v0.0.20'
          volumes:
            - type: bind
              source: ./conf.json
              target: /conf.json
          links:
            - 'product-db:product-db'
          ports:
            - '9090:9090'
        product-db:
          image: 'hashicorpdemoapp/product-api-db:v0.0.20'
          ports:
            - '5432:5432'
          environment:
            - POSTGRES_DB=products
            - POSTGRES_PASSWORD=password
            - POSTGRES_USER=postgres
        payments:
          image: 'hashicorpdemoapp/payments:latest'
    EOF_DOCKER_COMPOSE

    # Start Docker Compose
    cd /home/ec2-user/app
    sudo docker-compose up -d


  EOF
}


resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Allow HTTP and HTTPS traffic from the internet"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # open port 22 to enable instance connect
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}