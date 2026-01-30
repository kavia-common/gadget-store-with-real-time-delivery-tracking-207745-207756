#!/bin/bash

DB_NAME="myapp"
DB_USER="appuser"
DB_PASSWORD="dbuser123"
DB_PORT="5000"

echo "Starting MySQL setup..."

# Apply schema + seed after MySQL is reachable.
apply_schema_and_seed() {
    echo "Applying schema + seed data (idempotent)..."

    # ---- Core identity ----
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS users (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, email VARCHAR(255) NULL UNIQUE, name VARCHAR(255) NULL, is_guest TINYINT(1) NOT NULL DEFAULT 0, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB" ${DB_NAME}

    # ---- Catalog ----
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS product_categories (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, slug VARCHAR(100) NOT NULL UNIQUE, name VARCHAR(255) NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB" ${DB_NAME}

    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS products (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, category_id BIGINT UNSIGNED NULL, sku VARCHAR(64) NOT NULL UNIQUE, name VARCHAR(255) NOT NULL, description TEXT NULL, price_cents INT UNSIGNED NOT NULL, currency CHAR(3) NOT NULL DEFAULT 'USD', image_url VARCHAR(512) NULL, stock_qty INT NOT NULL DEFAULT 0, is_active TINYINT(1) NOT NULL DEFAULT 1, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP, CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES product_categories(id) ON DELETE SET NULL ON UPDATE CASCADE, INDEX idx_products_category_id (category_id), INDEX idx_products_active (is_active), FULLTEXT KEY ft_products_name_desc (name, description)) ENGINE=InnoDB" ${DB_NAME}

    # ---- Carts ----
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS carts (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, user_id BIGINT UNSIGNED NULL, guest_token CHAR(36) NULL, status ENUM('active','converted','abandoned') NOT NULL DEFAULT 'active', created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP, CONSTRAINT fk_carts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE, UNIQUE KEY uq_carts_guest_token (guest_token), INDEX idx_carts_user_id (user_id), INDEX idx_carts_status (status)) ENGINE=InnoDB" ${DB_NAME}

    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS cart_items (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, cart_id BIGINT UNSIGNED NOT NULL, product_id BIGINT UNSIGNED NOT NULL, quantity INT UNSIGNED NOT NULL DEFAULT 1, unit_price_cents INT UNSIGNED NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP, CONSTRAINT fk_cart_items_cart FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE ON UPDATE CASCADE, CONSTRAINT fk_cart_items_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT ON UPDATE CASCADE, UNIQUE KEY uq_cart_items_cart_product (cart_id, product_id), INDEX idx_cart_items_cart_id (cart_id), INDEX idx_cart_items_product_id (product_id)) ENGINE=InnoDB" ${DB_NAME}

    # ---- Orders ----
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS orders (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, order_number VARCHAR(32) NOT NULL UNIQUE, user_id BIGINT UNSIGNED NULL, guest_email VARCHAR(255) NULL, status ENUM('pending','paid','processing','shipped','delivered','cancelled','refunded') NOT NULL DEFAULT 'pending', subtotal_cents INT UNSIGNED NOT NULL DEFAULT 0, shipping_cents INT UNSIGNED NOT NULL DEFAULT 0, tax_cents INT UNSIGNED NOT NULL DEFAULT 0, total_cents INT UNSIGNED NOT NULL DEFAULT 0, currency CHAR(3) NOT NULL DEFAULT 'USD', shipping_name VARCHAR(255) NULL, shipping_phone VARCHAR(40) NULL, shipping_address1 VARCHAR(255) NULL, shipping_address2 VARCHAR(255) NULL, shipping_city VARCHAR(128) NULL, shipping_state VARCHAR(128) NULL, shipping_postal VARCHAR(32) NULL, shipping_country CHAR(2) NULL, placed_at TIMESTAMP NULL DEFAULT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP, CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE, INDEX idx_orders_user_id (user_id), INDEX idx_orders_status (status), INDEX idx_orders_placed_at (placed_at)) ENGINE=InnoDB" ${DB_NAME}

    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS order_items (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, order_id BIGINT UNSIGNED NOT NULL, product_id BIGINT UNSIGNED NULL, sku VARCHAR(64) NOT NULL, name VARCHAR(255) NOT NULL, quantity INT UNSIGNED NOT NULL, unit_price_cents INT UNSIGNED NOT NULL, line_total_cents INT UNSIGNED NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE, CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL ON UPDATE CASCADE, INDEX idx_order_items_order_id (order_id), INDEX idx_order_items_product_id (product_id)) ENGINE=InnoDB" ${DB_NAME}

    # ---- Delivery tracking ----
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS delivery_statuses (code VARCHAR(32) NOT NULL PRIMARY KEY, name VARCHAR(64) NOT NULL, description VARCHAR(255) NULL) ENGINE=InnoDB" ${DB_NAME}

    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS delivery_trackers (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, order_id BIGINT UNSIGNED NOT NULL, tracking_number VARCHAR(64) NULL UNIQUE, carrier VARCHAR(64) NULL, current_status_code VARCHAR(32) NOT NULL DEFAULT 'order_received', last_event_at TIMESTAMP NULL DEFAULT NULL, eta_date DATE NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP, CONSTRAINT fk_delivery_trackers_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE, CONSTRAINT fk_delivery_trackers_status FOREIGN KEY (current_status_code) REFERENCES delivery_statuses(code) ON DELETE RESTRICT ON UPDATE CASCADE, UNIQUE KEY uq_delivery_trackers_order (order_id), INDEX idx_delivery_trackers_status (current_status_code), INDEX idx_delivery_trackers_last_event (last_event_at)) ENGINE=InnoDB" ${DB_NAME}

    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "CREATE TABLE IF NOT EXISTS delivery_events (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tracker_id BIGINT UNSIGNED NOT NULL, status_code VARCHAR(32) NOT NULL, message VARCHAR(255) NULL, location VARCHAR(255) NULL, latitude DECIMAL(9,6) NULL, longitude DECIMAL(9,6) NULL, event_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, CONSTRAINT fk_delivery_events_tracker FOREIGN KEY (tracker_id) REFERENCES delivery_trackers(id) ON DELETE CASCADE ON UPDATE CASCADE, CONSTRAINT fk_delivery_events_status FOREIGN KEY (status_code) REFERENCES delivery_statuses(code) ON DELETE RESTRICT ON UPDATE CASCADE, INDEX idx_delivery_events_tracker_time (tracker_id, event_time), INDEX idx_delivery_events_status (status_code), INDEX idx_delivery_events_event_time (event_time)) ENGINE=InnoDB" ${DB_NAME}

    # ---- Minimal seed (stable IDs for predictable dev data) ----
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO product_categories (id, slug, name) VALUES (1,'gadgets','Gadgets')" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO product_categories (id, slug, name) VALUES (2,'accessories','Accessories')" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO product_categories (id, slug, name) VALUES (3,'retro','Retro Tech')" ${DB_NAME}

    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO products (id, category_id, sku, name, description, price_cents, currency, image_url, stock_qty, is_active) VALUES (1,1,'GAD-NEON-001','Neon Pulse Smartwatch','A retro-futuristic smartwatch with neon accents and synthwave vibes.',12999,'USD',NULL,25,1)" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO products (id, category_id, sku, name, description, price_cents, currency, image_url, stock_qty, is_active) VALUES (2,2,'ACC-PIXEL-002','PixelWave USB-C Cable','Durable braided cable with a pixel-art pattern.',1599,'USD',NULL,200,1)" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO products (id, category_id, sku, name, description, price_cents, currency, image_url, stock_qty, is_active) VALUES (3,3,'RET-CRT-003','Mini CRT Desk Display','A tiny desktop display that looks like a classic CRT. Perfect for lo-fi dashboards.',8999,'USD',NULL,40,1)" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO products (id, category_id, sku, name, description, price_cents, currency, image_url, stock_qty, is_active) VALUES (4,1,'GAD-DRONE-004','Pocket Recon Drone','Palm-sized drone with stabilized camera and instant live feed.',19999,'USD',NULL,15,1)" ${DB_NAME}

    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO delivery_statuses (code, name, description) VALUES ('order_received','Order received','We have received your order')" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO delivery_statuses (code, name, description) VALUES ('packed','Packed','Order packed and ready to ship')" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO delivery_statuses (code, name, description) VALUES ('in_transit','In transit','Package is on the move')" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO delivery_statuses (code, name, description) VALUES ('out_for_delivery','Out for delivery','Courier is about to arrive')" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO delivery_statuses (code, name, description) VALUES ('delivered','Delivered','Delivered to destination')" ${DB_NAME}
    mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} -e "INSERT IGNORE INTO delivery_statuses (code, name, description) VALUES ('exception','Exception','Shipment exception or delay')" ${DB_NAME}

    echo "Schema + seed applied."
}

# Check if MySQL is already running on the specified port
if sudo mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null; then
    echo "MySQL is already running!"

    # Try to verify the database exists
    if sudo mysql --socket=/var/run/mysqld/mysqld.sock -e "USE ${DB_NAME};" 2>/dev/null; then
        echo "Database ${DB_NAME} is accessible."
    fi

    # Ensure schema exists even if server was already running (common in CI/dev)
    apply_schema_and_seed

    echo ""
    echo "Database: ${DB_NAME}"
    echo "Root user: root (password: ${DB_PASSWORD})"
    echo "App user: appuser (password: ${DB_PASSWORD})"
    echo "Port: ${DB_PORT}"
    echo ""

    # Check if connection info file exists
    if [ -f "db_connection.txt" ]; then
        echo "To connect to the database, use:"
        echo "$(cat db_connection.txt)"
    else
        echo "To connect to the database, use:"
        echo "mysql -u root -p${DB_PASSWORD} -h localhost -P ${DB_PORT} ${DB_NAME}"
    fi

    echo ""
    echo "Script stopped - MySQL server already running."
    exit 0
fi

# Check if there's a MySQL process running on the specified port
if pgrep -f "mysqld.*--port=${DB_PORT}" > /dev/null 2>&1; then
    echo "Found existing MySQL process on port ${DB_PORT}"
    echo "Attempting to verify connection..."

    # Try to connect via TCP
    if mysql -u root -p${DB_PASSWORD} -h 127.0.0.1 -P ${DB_PORT} -e "SELECT 1;" 2>/dev/null; then
        echo "MySQL is accessible on port ${DB_PORT}."

        # Ensure schema exists
        apply_schema_and_seed

        echo "Script stopped - server already running."
        exit 0
    fi
fi

# Check if MySQL is running on default socket but different port
if [ -S /var/run/mysqld/mysqld.sock ]; then
    echo "Found MySQL socket, checking if it's using port ${DB_PORT}..."
    CURRENT_PORT=$(sudo mysql --socket=/var/run/mysqld/mysqld.sock -e "SHOW VARIABLES LIKE 'port';" 2>/dev/null | grep port | awk '{print $2}')
    if [ "$CURRENT_PORT" = "${DB_PORT}" ]; then
        echo "MySQL is already running on port ${DB_PORT}!"

        # Ensure schema exists
        apply_schema_and_seed

        echo "Script stopped - server already running."
        exit 0
    else
        echo "MySQL is running on different port ($CURRENT_PORT), stopping it first..."
        sudo mysqladmin shutdown --socket=/var/run/mysqld/mysqld.sock
        sleep 5
    fi
fi

# Initialize MySQL data directory if it doesn't exist
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MySQL..."
    sudo mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql
fi

# Start MySQL server in background using sudo
echo "Starting MySQL server..."
sudo mysqld --user=mysql --datadir=/var/lib/mysql --socket=/var/run/mysqld/mysqld.sock --pid-file=/var/run/mysqld/mysqld.pid --port=${DB_PORT} &

# Wait for MySQL to be ready
echo "Waiting for MySQL to start..."
sleep 5

# Check if MySQL is running using socket
for i in {1..15}; do
    if sudo mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null; then
        echo "MySQL is ready!"
        break
    fi
    echo "Waiting... ($i/15)"
    sleep 2
done

# Configure database and user - Fix MySQL 8.0 authentication
echo "Setting up database and fixing authentication..."
sudo mysql --socket=/var/run/mysqld/mysqld.sock << EOF
-- Fix root user authentication for MySQL 8.0
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';

-- Create database
CREATE DATABASE IF NOT EXISTS ${DB_NAME};

-- Create a new user for remote connections
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO 'appuser'@'%';

-- Grant privileges to root
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO 'root'@'localhost';

FLUSH PRIVILEGES;
EOF

# Save connection command to a file
echo "mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -P ${DB_PORT} ${DB_NAME}" > db_connection.txt
echo "Connection command saved to db_connection.txt"

# Save environment variables to a file
cat > db_visualizer/mysql.env << EOF
export MYSQL_URL="mysql://localhost:${DB_PORT}/${DB_NAME}"
export MYSQL_USER="${DB_USER}"
export MYSQL_PASSWORD="${DB_PASSWORD}"
export MYSQL_DB="${DB_NAME}"
export MYSQL_PORT="${DB_PORT}"
EOF

# Ensure schema/seed exist for application consumption
apply_schema_and_seed

echo "MySQL setup complete!"
echo "Database: ${DB_NAME}"
echo "Root user: root (password: ${DB_PASSWORD})"
echo "App user: appuser (password: ${DB_PASSWORD})"
echo "Port: ${DB_PORT}"
echo ""

echo "Environment variables saved to db_visualizer/mysql.env"
echo "To use with Node.js viewer, run: source db_visualizer/mysql.env"

echo "To connect to the database, use the following command:"
echo "$(cat db_connection.txt)"

echo ""
echo "MySQL is running in the background."
echo "You can now start your application."
