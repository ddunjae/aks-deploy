const express = require('express');
const cors = require('cors');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3001;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';

app.use(cors());
app.use(express.json());

// Health check endpoints for Kubernetes
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

app.get('/ready', (req, res) => {
  res.json({
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.get('/api/info', (req, res) => {
  res.json({
    hostname: os.hostname(),
    platform: os.platform(),
    version: APP_VERSION,
    environment: ENVIRONMENT,
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Sample data
let todos = [
  { id: 1, title: 'Learn Kubernetes', completed: true, createdAt: new Date().toISOString() },
  { id: 2, title: 'Deploy to AKS', completed: true, createdAt: new Date().toISOString() },
  { id: 3, title: 'Setup CI/CD Pipeline', completed: false, createdAt: new Date().toISOString() }
];

// Get all todos
app.get('/api/todos', (req, res) => {
  res.json({
    todos,
    count: todos.length,
    hostname: os.hostname()
  });
});

// Get single todo
app.get('/api/todos/:id', (req, res) => {
  const todo = todos.find(t => t.id === parseInt(req.params.id));
  if (!todo) {
    return res.status(404).json({ error: 'Todo not found' });
  }
  res.json(todo);
});

// Create todo
app.post('/api/todos', (req, res) => {
  const { title } = req.body;
  if (!title) {
    return res.status(400).json({ error: 'Title is required' });
  }

  const newTodo = {
    id: todos.length > 0 ? Math.max(...todos.map(t => t.id)) + 1 : 1,
    title,
    completed: false,
    createdAt: new Date().toISOString()
  };

  todos.push(newTodo);
  res.status(201).json(newTodo);
});

// Update todo
app.put('/api/todos/:id', (req, res) => {
  const todo = todos.find(t => t.id === parseInt(req.params.id));
  if (!todo) {
    return res.status(404).json({ error: 'Todo not found' });
  }

  const { title, completed } = req.body;
  if (title !== undefined) todo.title = title;
  if (completed !== undefined) todo.completed = completed;

  res.json(todo);
});

// Delete todo
app.delete('/api/todos/:id', (req, res) => {
  const index = todos.findIndex(t => t.id === parseInt(req.params.id));
  if (index === -1) {
    return res.status(404).json({ error: 'Todo not found' });
  }

  todos.splice(index, 1);
  res.json({ message: 'Todo deleted successfully' });
});

// Serve static files from React build in production
if (process.env.NODE_ENV === 'production') {
  app.use(express.static('public'));

  app.get('*', (req, res) => {
    res.sendFile(__dirname + '/public/index.html');
  });
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${ENVIRONMENT}`);
  console.log(`Version: ${APP_VERSION}`);
});
