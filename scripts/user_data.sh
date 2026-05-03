#!/bin/bash
yum update -y
amazon-linux-extras install nginx1 -y
mkdir -p /usr/share/nginx/html
cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>EC2 Status</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #0d0d0d; color: #e0e0e0; font-family: 'Courier New', monospace; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
    .card { border: 1px solid #2a2a2a; border-radius: 8px; padding: 2rem 2.5rem; background: #141414; min-width: 360px; box-shadow: 0 0 30px rgba(99,102,241,0.08); }
    h1 { color: #6366f1; font-size: 1.2rem; margin-bottom: 1.5rem; letter-spacing: 2px; }
    .status { text-align: center; color: #22c55e; font-size: 0.85rem; letter-spacing: 1px; margin-top: 1rem; }
    p { color: #888; font-size: 0.85rem; margin-top: 0.5rem; text-align: center; }
  </style>
</head>
<body>
  <div class="card">
    <h1>// TERRAFORM 2-TIER AWS</h1>
    <div class="status">● EC2 INSTANCE ONLINE</div>
    <p>Provisioned via Terraform · Served by nginx</p>
  </div>
</body>
</html>
EOF
systemctl enable nginx
systemctl start nginx