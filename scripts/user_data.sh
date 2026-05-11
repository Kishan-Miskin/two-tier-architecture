#!/bin/bash
set -euxo pipefail

# ── Terraform-injected variables ─────────────────────────────────────────────
DB_HOST="${db_host}"
DB_NAME="${db_name}"
DB_USER="${db_username}"
DB_PASS="${db_password}"

# ── System packages ───────────────────────────────────────────────────────────
yum update -y
yum install -y python3 python3-pip
amazon-linux-extras install nginx1 -y

# ── App directory ─────────────────────────────────────────────────────────────
mkdir -p /opt/nimbusboard
cd /opt/nimbusboard

python3 -m venv venv
/opt/nimbusboard/venv/bin/pip install --quiet flask pymysql gunicorn cryptography

# ── Write environment file ────────────────────────────────────────────────────
cat > /opt/nimbusboard/.env << ENVEOF
DB_HOST=$DB_HOST
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
ENVEOF
chmod 600 /opt/nimbusboard/.env

# ── Write Flask app ───────────────────────────────────────────────────────────
cat > /opt/nimbusboard/app.py << 'PYEOF'
import os, pymysql
from flask import Flask, request, jsonify, render_template_string

app = Flask(__name__)

def db():
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        database=os.environ["DB_NAME"],
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=10,
    )

def init_db():
    conn = db()
    with conn.cursor() as c:
        c.execute("""
            CREATE TABLE IF NOT EXISTS tasks (
                id          INT AUTO_INCREMENT PRIMARY KEY,
                title       VARCHAR(255) NOT NULL,
                description TEXT,
                priority    ENUM('low','medium','high') DEFAULT 'medium',
                status      ENUM('pending','in_progress','done') DEFAULT 'pending',
                created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
    conn.commit()
    conn.close()

init_db()

TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>NimbusBoard</title>
<style>
  :root {
    --bg: #0d0f14; --surface: #161920; --surface2: #1e222d;
    --border: #2a2f3d; --text: #e8eaf0; --muted: #6b7280;
    --accent: #6366f1; --accent-dim: #4f52c4;
    --green: #10b981; --amber: #f59e0b; --red: #ef4444; --blue: #3b82f6;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; min-height: 100vh; }
  header { background: var(--surface); border-bottom: 1px solid var(--border); padding: 0 2rem; display: flex; align-items: center; justify-content: space-between; height: 58px; }
  .logo { font-size: 17px; font-weight: 600; letter-spacing: -0.3px; display: flex; align-items: center; gap: 8px; }
  .logo-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--accent); }
  .badge { font-size: 11px; background: #1e2035; color: var(--accent); padding: 3px 8px; border-radius: 12px; border: 1px solid #3d3f6e; }
  main { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem; }
  .stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 2rem; }
  .stat { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 1rem 1.2rem; }
  .stat-label { font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; }
  .stat-value { font-size: 26px; font-weight: 600; }
  .stat-value.green { color: var(--green); }
  .stat-value.amber { color: var(--amber); }
  .stat-value.blue { color: var(--blue); }
  .panel { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; margin-bottom: 1.5rem; }
  .panel-header { padding: 1rem 1.25rem; border-bottom: 1px solid var(--border); font-size: 14px; font-weight: 500; }
  .panel-body { padding: 1.25rem; }
  .form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 12px; }
  .form-group { display: flex; flex-direction: column; gap: 6px; }
  label { font-size: 12px; color: var(--muted); }
  input[type=text], textarea, select {
    background: var(--surface2); border: 1px solid var(--border); color: var(--text);
    padding: 8px 12px; border-radius: 8px; font-size: 14px; width: 100%; outline: none;
    transition: border-color 0.15s;
  }
  input[type=text]:focus, textarea:focus, select:focus { border-color: var(--accent); }
  textarea { resize: vertical; min-height: 70px; }
  .btn { display: inline-flex; align-items: center; gap: 6px; padding: 8px 16px; border-radius: 8px; font-size: 14px; font-weight: 500; border: none; cursor: pointer; transition: opacity 0.15s; }
  .btn:hover { opacity: 0.85; }
  .btn-primary { background: var(--accent); color: #fff; }
  .btn-sm { padding: 4px 10px; font-size: 12px; border-radius: 6px; }
  .btn-ghost { background: var(--surface2); color: var(--muted); border: 1px solid var(--border); }
  .task-list { display: flex; flex-direction: column; gap: 8px; }
  .task { background: var(--surface2); border: 1px solid var(--border); border-radius: 10px; padding: 1rem 1.25rem; display: flex; align-items: flex-start; gap: 1rem; transition: border-color 0.15s; }
  .task:hover { border-color: #3a3f55; }
  .task.done { opacity: 0.45; }
  .task-main { flex: 1; }
  .task-title { font-size: 14px; font-weight: 500; margin-bottom: 4px; }
  .task.done .task-title { text-decoration: line-through; }
  .task-desc { font-size: 13px; color: var(--muted); }
  .task-meta { display: flex; align-items: center; gap: 8px; margin-top: 8px; }
  .chip { font-size: 11px; padding: 2px 8px; border-radius: 20px; font-weight: 500; }
  .chip.pending { background: #1c2035; color: #818cf8; }
  .chip.in_progress { background: #1c2a1c; color: var(--green); }
  .chip.done { background: #2a2a1c; color: var(--amber); }
  .chip.high { background: #2a1c1c; color: var(--red); }
  .chip.medium { background: #1c1c2a; color: #93c5fd; }
  .chip.low { background: #1c2a24; color: #6ee7b7; }
  .task-actions { display: flex; gap: 6px; flex-shrink: 0; }
  .ts { font-size: 12px; color: var(--muted); }
  .empty { text-align: center; padding: 3rem; color: var(--muted); font-size: 14px; }
  @media (max-width: 600px) { .stats { grid-template-columns: 1fr 1fr; } .form-row { grid-template-columns: 1fr; } }
</style>
</head>
<body>
<header>
  <div class="logo"><div class="logo-dot"></div>NimbusBoard</div>
  <span class="badge">AWS 2-Tier ✦ RDS Connected</span>
</header>
<main>
  {% set total = tasks|length %}
  {% set pending = tasks|selectattr('status','eq','pending')|list|length %}
  {% set inprog  = tasks|selectattr('status','eq','in_progress')|list|length %}
  {% set done    = tasks|selectattr('status','eq','done')|list|length %}
  <div class="stats">
    <div class="stat"><div class="stat-label">Total</div><div class="stat-value">{{ total }}</div></div>
    <div class="stat"><div class="stat-label">Pending</div><div class="stat-value blue">{{ pending }}</div></div>
    <div class="stat"><div class="stat-label">In Progress</div><div class="stat-value amber">{{ inprog }}</div></div>
    <div class="stat"><div class="stat-label">Done</div><div class="stat-value green">{{ done }}</div></div>
  </div>
  <div class="panel">
    <div class="panel-header">New task</div>
    <div class="panel-body">
      <div class="form-row">
        <div class="form-group" style="grid-column:1/-1">
          <label>Title</label>
          <input type="text" id="t-title" placeholder="What needs to be done?"/>
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Description</label>
          <textarea id="t-desc" placeholder="Optional details…"></textarea>
        </div>
        <div class="form-group">
          <label>Priority</label>
          <select id="t-priority">
            <option value="medium">Medium</option>
            <option value="high">High</option>
            <option value="low">Low</option>
          </select>
        </div>
      </div>
      <button class="btn btn-primary" onclick="createTask()">+ Add task</button>
    </div>
  </div>
  <div class="panel">
    <div class="panel-header">Tasks</div>
    <div class="panel-body">
      {% if tasks %}
      <div class="task-list">
        {% for t in tasks %}
        <div class="task {{ t.status }}" id="task-{{ t.id }}">
          <div class="task-main">
            <div class="task-title">{{ t.title }}</div>
            {% if t.description %}<div class="task-desc">{{ t.description }}</div>{% endif %}
            <div class="task-meta">
              <span class="chip {{ t.status }}">{{ t.status.replace('_',' ') }}</span>
              <span class="chip {{ t.priority }}">{{ t.priority }}</span>
              <span class="ts">{{ t.created_at.strftime('%d %b %Y') }}</span>
            </div>
          </div>
          <div class="task-actions">
            {% if t.status != 'in_progress' and t.status != 'done' %}
            <button class="btn btn-sm btn-ghost" onclick="setStatus({{ t.id }}, 'in_progress')">▶ Start</button>
            {% endif %}
            {% if t.status != 'done' %}
            <button class="btn btn-sm btn-ghost" onclick="setStatus({{ t.id }}, 'done')">✓ Done</button>
            {% endif %}
            <button class="btn btn-sm btn-ghost" onclick="deleteTask({{ t.id }})">✕</button>
          </div>
        </div>
        {% endfor %}
      </div>
      {% else %}
      <div class="empty">No tasks yet — add one above.</div>
      {% endif %}
    </div>
  </div>
</main>
<script>
  async function createTask() {
    const title = document.getElementById('t-title').value.trim();
    if (!title) return;
    await fetch('/tasks', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        title,
        description: document.getElementById('t-desc').value,
        priority: document.getElementById('t-priority').value
      })
    });
    location.reload();
  }
  async function setStatus(id, status) {
    await fetch('/tasks/' + id + '/status', {
      method: 'PUT',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({status})
    });
    location.reload();
  }
  async function deleteTask(id) {
    await fetch('/tasks/' + id, {method: 'DELETE'});
    document.getElementById('task-' + id).remove();
  }
</script>
</body>
</html>
"""

@app.route('/')
def index():
    conn = db()
    with conn.cursor() as c:
        c.execute("SELECT * FROM tasks ORDER BY created_at DESC")
        tasks = c.fetchall()
    conn.close()
    return render_template_string(TEMPLATE, tasks=tasks)

@app.route('/tasks', methods=['POST'])
def create_task():
    d = request.json
    conn = db()
    with conn.cursor() as c:
        c.execute("INSERT INTO tasks (title,description,priority) VALUES (%s,%s,%s)",
                  (d['title'], d.get('description',''), d.get('priority','medium')))
    conn.commit(); conn.close()
    return jsonify(ok=True)

@app.route('/tasks/<int:tid>/status', methods=['PUT'])
def update_status(tid):
    conn = db()
    with conn.cursor() as c:
        c.execute("UPDATE tasks SET status=%s WHERE id=%s", (request.json['status'], tid))
    conn.commit(); conn.close()
    return jsonify(ok=True)

@app.route('/tasks/<int:tid>', methods=['DELETE'])
def delete_task(tid):
    conn = db()
    with conn.cursor() as c:
        c.execute("DELETE FROM tasks WHERE id=%s", (tid,))
    conn.commit(); conn.close()
    return jsonify(ok=True)

@app.route('/health')
def health():
    return jsonify(status='ok')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYEOF

# ── Systemd service ───────────────────────────────────────────────────────────
cat > /etc/systemd/system/nimbusboard.service << 'SVCEOF'
[Unit]
Description=NimbusBoard
After=network.target

[Service]
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/nimbusboard
EnvironmentFile=/opt/nimbusboard/.env
ExecStart=/opt/nimbusboard/venv/bin/gunicorn \
    --workers 2 \
    --bind 127.0.0.1:5000 \
    --timeout 60 \
    --access-logfile /var/log/nimbusboard.log \
    app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

# ── Nginx config (Amazon Linux uses conf.d, not sites-enabled) ────────────────
cat > /etc/nginx/conf.d/nimbusboard.conf << 'NGEOF'
server {
    listen 80 default_server;
    server_name _;

    location /health {
        access_log off;
        proxy_pass http://127.0.0.1:5000/health;
    }

    location / {
        proxy_pass         http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
    }
}
NGEOF

# Remove default nginx welcome page
rm -f /etc/nginx/conf.d/default.conf

# ── Permissions and start ─────────────────────────────────────────────────────
chown -R ec2-user:ec2-user /opt/nimbusboard

# Fix log file BEFORE starting service
touch /var/log/nimbusboard.log
chown ec2-user:ec2-user /var/log/nimbusboard.log

systemctl daemon-reload
systemctl enable nimbusboard
systemctl start nimbusboard
systemctl enable nginx
systemctl start nginx
