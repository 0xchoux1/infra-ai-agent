#!/bin/bash
set -e

# ログ設定
exec 1> >(logger -s -t startup-script) 2>&1

echo "Starting WordPress web server setup..."

# 環境変数
ENV="${env}"
DB_HOST="${db_host}"
WAZUH_MANAGER="${wazuh_manager}"
PROJECT_ID="${project_id}"
NFS_IP="${nfs_ip}"
NFS_PATH="${nfs_path}"
DOMAINS_JSON='${domains_json}'

# システム更新
apt-get update
apt-get upgrade -y

# Google Cloud SDK リポジトリ追加
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
  tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
  apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# パッケージリスト更新
apt-get update

# 必須パッケージインストール（Cloud SDK含む）
apt-get install -y \
  nginx \
  php8.2-fpm \
  php8.2-mysql \
  php8.2-curl \
  php8.2-gd \
  php8.2-mbstring \
  php8.2-xml \
  php8.2-xmlrpc \
  php8.2-soap \
  php8.2-intl \
  php8.2-zip \
  php8.2-bcmath \
  php8.2-imagick \
  mysql-client \
  nfs-common \
  curl \
  wget \
  unzip \
  git \
  jq \
  google-cloud-sdk

# WP-CLIインストール
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# NFSマウント（Cloud Filestore）
mkdir -p /var/www/wordpress
if ! mount | grep -q '/var/www/wordpress'; then
  mount -t nfs -o rw,hard,intr,rsize=1048576,wsize=1048576 \
    $${NFS_IP}:$${NFS_PATH} /var/www/wordpress
  
  # /etc/fstab に追加（再起動時も自動マウント）
  echo "$${NFS_IP}:$${NFS_PATH} /var/www/wordpress nfs rw,hard,intr,rsize=1048576,wsize=1048576 0 0" >> /etc/fstab
fi

# ドメインリストを取得（メタデータまたはテンプレート変数から）
if [ -z "$DOMAINS_JSON" ]; then
  # メタデータから取得（フォールバック）
  DOMAINS_JSON=$(curl -s -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/attributes/domains)
fi

# ドメイン数を取得
DOMAIN_COUNT=$(echo "$DOMAINS_JSON" | jq '. | length')

echo "Setting up $DOMAIN_COUNT WordPress sites..."

# ドメイン数分のディレクトリ作成
for i in $(seq 1 $DOMAIN_COUNT); do
  mkdir -p /var/www/wordpress/site$${i}
done

chown -R www-data:www-data /var/www/wordpress

# Nginx基本設定
cat > /etc/nginx/nginx.conf << 'NGINX_CONF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # ログ設定
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # Gzip圧縮
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    # サイト設定を読み込み
    include /etc/nginx/sites-enabled/*;
}
NGINX_CONF

# Health Checkエンドポイント
cat > /etc/nginx/sites-available/health << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location / {
        return 404;
    }
}
EOF

# Nginx設定テンプレート生成関数
generate_site_config() {
  local site_num=$1
  local domain=$2
  
  cat > /etc/nginx/sites-available/site$${site_num} << SITE_EOF
server {
    listen 80;
    server_name $${domain};
    
    root /var/www/wordpress/site$${site_num};
    index index.php index.html;
    
    # WordPress Permalinks
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    # PHP処理
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        
        # Cache-Control（WordPress側で動的設定）
        fastcgi_hide_header Cache-Control;
    }
    
    # 静的ファイルキャッシュ
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, max-age=31536000, immutable";
        access_log off;
    }
    
    # 管理画面（キャッシュ無効）
    location ~ ^/wp-(admin|login|cron) {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    # セキュリティヘッダー
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # アップロードサイズ制限
    client_max_body_size 64M;
}
SITE_EOF
}

# ドメインリストを配列に変換してNginx設定生成
site_num=0
echo "$DOMAINS_JSON" | jq -r '.[]' | while IFS= read -r domain; do
  site_num=$((site_num + 1))
  echo "Configuring site$${site_num}: $${domain}"
  generate_site_config $site_num "$domain"
  ln -sf /etc/nginx/sites-available/site$${site_num} /etc/nginx/sites-enabled/site$${site_num}
done

ln -sf /etc/nginx/sites-available/health /etc/nginx/sites-enabled/health
rm -f /etc/nginx/sites-enabled/default

# PHP-FPM設定（OPcache最適化）
cat > /etc/php/8.2/fpm/conf.d/99-wordpress-optimize.ini << 'PHP_INI'
; OPcache設定
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.revalidate_freq=2
opcache.fast_shutdown=1

; アップロード設定
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 300

; セッション設定
session.cookie_httponly = 1
session.cookie_secure = 1
PHP_INI

# WordPress初期セットアップスクリプト生成
cat > /usr/local/bin/setup-wordpress-site.sh << SETUP_SCRIPT
#!/bin/bash
# WordPress サイトセットアップスクリプト
# 使用方法: setup-wordpress-site.sh <site_num> <domain> <site_title>

SITE_NUM=$1
DOMAIN=$2
SITE_TITLE=$3

if [ -z "$SITE_NUM" ] || [ -z "$DOMAIN" ] || [ -z "$SITE_TITLE" ]; then
  echo "Usage: $0 <site_num> <domain> <site_title>"
  echo "Example: $0 1 example.com 'My Blog'"
  exit 1
fi

SITE_DIR="/var/www/wordpress/site$${SITE_NUM}"
DB_NAME="wordpress_site_$${SITE_NUM}"
DB_USER="wp_user_$${SITE_NUM}"

# Secret Managerから DB パスワード取得
DB_PASS=$(gcloud secrets versions access latest \
  --secret="$${ENV}-wordpress-db-password-$${SITE_NUM}" \
  --project="$${PROJECT_ID}")

# WordPress ダウンロード
cd $SITE_DIR
if [ ! -f wp-config.php ]; then
  sudo -u www-data wp core download
  
  # wp-config.php 作成
  sudo -u www-data wp config create \
    --dbname="$${DB_NAME}" \
    --dbuser="$${DB_USER}" \
    --dbpass="$${DB_PASS}" \
    --dbhost="$${DB_HOST}"
  
  # 管理者パスワード生成
  ADMIN_PASSWORD=$(openssl rand -base64 32)
  
  # WordPress インストール
  sudo -u www-data wp core install \
    --url="https://$${DOMAIN}" \
    --title="$${SITE_TITLE}" \
    --admin_user="admin" \
    --admin_password="$${ADMIN_PASSWORD}" \
    --admin_email="admin@$${DOMAIN}"
  
  # 管理者パスワードをSecret Managerに保存
  echo -n "$${ADMIN_PASSWORD}" | gcloud secrets create \
    "$${ENV}-wordpress-admin-password-$${SITE_NUM}" \
    --data-file=- \
    --project="$${PROJECT_ID}" 2>/dev/null || \
  echo -n "$${ADMIN_PASSWORD}" | gcloud secrets versions add \
    "$${ENV}-wordpress-admin-password-$${SITE_NUM}" \
    --data-file=- \
    --project="$${PROJECT_ID}"
  
  # Cache-Control プラグインインストール（オプション）
  # 実際のプラグインが決まったら、以下のようにインストール
  # sudo -u www-data wp plugin install nginx-helper --activate
  # sudo -u www-data wp plugin install w3-total-cache --activate
  
  echo "=========================================="
  echo "WordPress site $${SITE_NUM} installed successfully!"
  echo "URL: https://$${DOMAIN}"
  echo "Admin User: admin"
  echo "Admin Password: Saved to Secret Manager"
  echo "  Retrieve with: gcloud secrets versions access latest --secret=$${ENV}-wordpress-admin-password-$${SITE_NUM}"
  echo "=========================================="
else
  echo "WordPress already installed in $${SITE_DIR}"
fi
SETUP_SCRIPT

chmod +x /usr/local/bin/setup-wordpress-site.sh

# サービス再起動
systemctl restart php8.2-fpm
systemctl restart nginx
systemctl enable nginx php8.2-fpm

# Cloud Logging Agentインストール
curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
bash add-logging-agent-repo.sh --also-install

# Wazuh Agentインストール
if [ ! -z "$WAZUH_MANAGER" ]; then
  curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
  echo "deb https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
  apt-get update
  WAZUH_MANAGER="$WAZUH_MANAGER" apt-get install -y wazuh-agent
  systemctl daemon-reload
  systemctl enable wazuh-agent
  systemctl start wazuh-agent
fi

echo "Startup script completed successfully!"

