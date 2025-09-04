# 🌐 Setup Ngrok for NoctisPro Online Access

## Step 1: Get Your Ngrok Auth Token

1. **Visit ngrok dashboard**: https://dashboard.ngrok.com/get-started/your-authtoken
2. **Sign up or log in** to your ngrok account (it's free!)
3. **Copy your auth token** from the dashboard

## Step 2: Configure Ngrok (Choose one method)

### Method A: Quick Setup (Recommended)
```bash
# Replace YOUR_AUTH_TOKEN with the token you copied
cd /workspace
./ngrok config add-authtoken YOUR_AUTH_TOKEN
```

### Method B: Interactive Setup
```bash
cd /workspace
./configure_ngrok_auth.sh
```

## Step 3: Start Ngrok Tunnel
```bash
cd /workspace
./start_ngrok_tunnel.sh
```

## Step 4: Get Your Public URL
```bash
cd /workspace
./get_public_url.sh
```

---

## 🚀 Quick One-Liner (after getting auth token)
```bash
cd /workspace && ./ngrok config add-authtoken YOUR_AUTH_TOKEN && ./ngrok http 8000 --log stdout &
```

Then check your public URL:
```bash
curl -s http://localhost:4040/api/tunnels | python3 -c "import json,sys; data=json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else 'No active tunnels')"
```

---

## 📋 What You'll Get
- **Free ngrok account**: No cost, just requires signup
- **Public HTTPS URL**: Like `https://abc123.ngrok-free.app`
- **Access from anywhere**: Share your NoctisPro with anyone
- **Automatic SSL**: HTTPS encryption included

## 🔧 Troubleshooting
If you have issues, check:
- Your auth token is correct
- NoctisPro is running on port 8000
- No firewall blocking connections