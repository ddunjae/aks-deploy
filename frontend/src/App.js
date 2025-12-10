import React, { useState, useEffect } from 'react';

const API_URL = process.env.REACT_APP_API_URL || '';

function App() {
  const [todos, setTodos] = useState([]);
  const [newTodo, setNewTodo] = useState('');
  const [serverInfo, setServerInfo] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch todos and server info on mount
  useEffect(() => {
    fetchTodos();
    fetchServerInfo();
  }, []);

  const fetchServerInfo = async () => {
    try {
      const response = await fetch(`${API_URL}/api/info`);
      const data = await response.json();
      setServerInfo(data);
    } catch (err) {
      console.error('Failed to fetch server info:', err);
    }
  };

  const fetchTodos = async () => {
    try {
      setLoading(true);
      const response = await fetch(`${API_URL}/api/todos`);
      const data = await response.json();
      setTodos(data.todos);
      setError(null);
    } catch (err) {
      setError('Failed to fetch todos. Please try again.');
      console.error('Failed to fetch todos:', err);
    } finally {
      setLoading(false);
    }
  };

  const addTodo = async (e) => {
    e.preventDefault();
    if (!newTodo.trim()) return;

    try {
      const response = await fetch(`${API_URL}/api/todos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: newTodo })
      });

      if (response.ok) {
        const todo = await response.json();
        setTodos([...todos, todo]);
        setNewTodo('');
      }
    } catch (err) {
      setError('Failed to add todo. Please try again.');
    }
  };

  const toggleTodo = async (id) => {
    const todo = todos.find(t => t.id === id);
    if (!todo) return;

    try {
      const response = await fetch(`${API_URL}/api/todos/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ completed: !todo.completed })
      });

      if (response.ok) {
        setTodos(todos.map(t =>
          t.id === id ? { ...t, completed: !t.completed } : t
        ));
      }
    } catch (err) {
      setError('Failed to update todo. Please try again.');
    }
  };

  const deleteTodo = async (id) => {
    try {
      const response = await fetch(`${API_URL}/api/todos/${id}`, {
        method: 'DELETE'
      });

      if (response.ok) {
        setTodos(todos.filter(t => t.id !== id));
      }
    } catch (err) {
      setError('Failed to delete todo. Please try again.');
    }
  };

  const completedCount = todos.filter(t => t.completed).length;

  if (loading) {
    return (
      <div className="app">
        <div className="loading">Loading...</div>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="header">
        <h1>AKS Todo App</h1>
        <p>A simple todo application running on Azure Kubernetes Service</p>
      </header>

      {serverInfo && (
        <div className="server-info">
          <h3>Server Information</h3>
          <div className="info-grid">
            <div className="info-item">
              <label>Hostname (Pod)</label>
              <span>{serverInfo.hostname}</span>
            </div>
            <div className="info-item">
              <label>Environment</label>
              <span>{serverInfo.environment}</span>
            </div>
            <div className="info-item">
              <label>Version</label>
              <span>{serverInfo.version}</span>
            </div>
            <div className="info-item">
              <label>Platform</label>
              <span>{serverInfo.platform}</span>
            </div>
          </div>
        </div>
      )}

      <div className="todo-container">
        {error && <div className="error">{error}</div>}

        <form className="add-todo-form" onSubmit={addTodo}>
          <input
            type="text"
            value={newTodo}
            onChange={(e) => setNewTodo(e.target.value)}
            placeholder="What needs to be done?"
          />
          <button type="submit" disabled={!newTodo.trim()}>
            Add Todo
          </button>
        </form>

        {todos.length === 0 ? (
          <div className="empty-state">
            <p>No todos yet. Add one above!</p>
          </div>
        ) : (
          <>
            <ul className="todo-list">
              {todos.map(todo => (
                <li key={todo.id} className={`todo-item ${todo.completed ? 'completed' : ''}`}>
                  <div
                    className={`todo-checkbox ${todo.completed ? 'checked' : ''}`}
                    onClick={() => toggleTodo(todo.id)}
                  />
                  <div className="todo-content">
                    <div className="todo-title">{todo.title}</div>
                    <div className="todo-date">
                      {new Date(todo.createdAt).toLocaleDateString('ko-KR', {
                        year: 'numeric',
                        month: 'long',
                        day: 'numeric'
                      })}
                    </div>
                  </div>
                  <button
                    className="todo-delete"
                    onClick={() => deleteTodo(todo.id)}
                  >
                    Delete
                  </button>
                </li>
              ))}
            </ul>

            <div className="todo-stats">
              <span>{todos.length} total</span>
              <span>{completedCount} completed</span>
              <span>{todos.length - completedCount} remaining</span>
            </div>
          </>
        )}
      </div>

      <footer className="footer">
        <p>
          Running on <strong>AKS</strong> |
          Built with React & Node.js |
          <a href="https://github.com/ddunjae/aks-deploy" target="_blank" rel="noopener noreferrer"> GitHub</a>
        </p>
      </footer>
    </div>
  );
}

export default App;
