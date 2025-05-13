cat > user_data.sh << 'EOF'
#!/bin/bash
# Actualizar el sistema
sudo yum update -y

# Instalar Docker
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Instalar NGINX
sudo yum install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Instalar utilidades para EFS
sudo yum install -y amazon-efs-utils

# Clonar el repositorio
git clone https://github.com/Alkran93/bookstore-monolith.git /tmp/bookstore-monolith
sudo mkdir -p /app
sudo cp -r /tmp/bookstore-monolith/* /app/
cd /app

# Montar EFS
sudo mkdir -p /mnt/efs
sudo mount -t efs EFS_ID:/ /mnt/efs
echo "EFS_ID:/ /mnt/efs efs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Crear archivo .env para la aplicación
cat > /app/.env << 'ENVFILE'
MYSQL_HOST=RDS_ENDPOINT
MYSQL_USER=DB_USERNAME
MYSQL_PASSWORD=DB_PASSWORD
MYSQL_DATABASE=bookstore
MYSQL_ROOT_PASSWORD=example
FLASK_APP=app.py
FLASK_DEBUG=1
ENVFILE

# Configurar NGINX
cat > /etc/nginx/conf.d/default.conf << 'NGINXCONF'
server {
    listen 80;
    server_name proyecto2.shop www.proyecto2.shop;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXCONF

sudo systemctl restart nginx

# Iniciar la aplicación
cd /app
docker-compose up -d
EOF
