-- ══════════════════════════════════════
-- E-COMMERCE SCHEMA
-- ══════════════════════════════════════

CREATE TABLE customers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) UNIQUE NOT NULL,
  country VARCHAR(50) NOT NULL,
  city VARCHAR(100),
  signup_date DATE NOT NULL DEFAULT CURRENT_DATE,
  is_premium BOOLEAN DEFAULT false
);

CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(80) NOT NULL,
  parent_id INTEGER REFERENCES categories(id)
);

CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  category_id INTEGER REFERENCES categories(id),
  price NUMERIC(10,2) NOT NULL,
  stock_quantity INTEGER DEFAULT 0,
  created_at DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  customer_id INTEGER REFERENCES customers(id),
  order_date DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'completed'
    CHECK (status IN ('pending','processing','completed','cancelled','refunded')),
  shipping_country VARCHAR(50),
  total_amount NUMERIC(10,2)
);

CREATE TABLE order_items (
  id SERIAL PRIMARY KEY,
  order_id INTEGER REFERENCES orders(id),
  product_id INTEGER REFERENCES products(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(10,2) NOT NULL
);

-- ══════════════════════════════════════
