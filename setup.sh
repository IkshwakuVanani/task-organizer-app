#!/usr/bin/env bash
set -e

echo "🚀 Starting setup for task-organizer-app..."

# 1. Create backend directory
echo "🔧 Creating backend scaffold..."
mkdir -p backend
cat > backend/schema.sql << 'EOF'
CREATE DATABASE IF NOT EXISTS task_organizer_db;
USE task_organizer_db;

CREATE TABLE IF NOT EXISTS tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  due_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

cat > backend/.env.example << 'EOF'
# Copy this to .env and fill in your credentials
DB_HOST=127.0.0.1
DB_USER=user
DB_PASS=pass
DB_NAME=task_organizer_db
PORT=4000
EOF

cat > backend/server.js << 'EOF'
require('dotenv').config();
const express = require('express');
const mysql   = require('mysql2/promise');
const app     = express();

app.use(express.json());

const pool = mysql.createPool({
  host:     process.env.DB_HOST,
  user:     process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
});

app.get('/api/tasks', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM tasks ORDER BY due_date ASC');
  res.json(rows);
});

app.post('/api/tasks', async (req, res) => {
  const { title, due_date } = req.body;
  const [result] = await pool.execute(
    'INSERT INTO tasks (title,due_date) VALUES (?,?)',
    [title, due_date]
  );
  const [task] = await pool.query('SELECT * FROM tasks WHERE id=?', [result.insertId]);
  res.json(task[0]);
});

app.put('/api/tasks/:id', async (req, res) => {
  const { id } = req.params;
  const { title, due_date, completed } = req.body;
  await pool.execute(
    'UPDATE tasks SET title=?, due_date=?, completed=? WHERE id=?',
    [title, due_date, completed ? 1 : 0, id]
  );
  const [task] = await pool.query('SELECT * FROM tasks WHERE id=?', [id]);
  res.json(task[0]);
});

app.delete('/api/tasks/:id', async (req, res) => {
  const { id } = req.params;
  await pool.execute('DELETE FROM tasks WHERE id=?', [id]);
  res.sendStatus(204);
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(\`Backend running on http://localhost:\${PORT}\`));
EOF

# 2. Initialize backend npm & install deps
echo "📦 Installing backend dependencies..."
cd backend
npm init -y > /dev/null
npm install express mysql2 dotenv
npm install --save-dev nodemon
cd ..

# 3. Bootstrap frontend with CRA
echo "⚛️  Bootstrapping React frontend..."
npx create-react-app frontend --use-npm

# 4. Final instructions
cat << 'INSTR'

✅ Setup complete!

Next steps:

1. Copy & configure your backend env:
   cd backend
   cp .env.example .env
   # then edit .env with your real MySQL credentials

2. Import the DB schema:
   mysql -h $DB_HOST -u $DB_USER -p$DB_PASS < schema.sql

3. Start the backend server:
   cd backend
   npx nodemon server.js

4. Start the React app:
   cd frontend
   npm start

Your Task Organizer will be running on two ports:
- Backend API:  http://localhost:4000
- Frontend app: http://localhost:3000

INSTR
