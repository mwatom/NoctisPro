### Windows Server one-shot deployment

Requirements:
- Windows Server 2019/2022
- Run PowerShell as Administrator

Steps:
1) Copy this repository to the server, e.g., `C:\\noctis`.
2) Open an elevated PowerShell and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
powershell -ExecutionPolicy Bypass -NoProfile -File C:\noctis\deployment\windows\Deploy-Windows.ps1 -RepoRoot C:\noctis -AppName NoctisPro -Port 8000 -SuperuserUsername admin -SuperuserPassword "Admin123!" -SuperuserEmail "admin@example.com"
```

What it does:
- Installs Python 3.10
- Creates a virtualenv and installs Windows-friendly dependencies from `requirements-windows.txt`
- Runs migrations, collects static, and creates a Django superuser
- Runs the app via Waitress as a Windows service
- Starts a Cloudflare Quick Tunnel as a Windows service
- Prints a public HTTPS URL at the end (e.g., `https://xxxx.trycloudflare.com`)

Where to look if something fails:
- App logs: `C:\\logs\\NoctisPro\\app-err.log` and `app-out.log`
- Tunnel logs: `C:\\logs\\NoctisPro\\cloudflared-err.log` and `cloudflared-out.log`
- Services: open `services.msc` and check `NoctisPro-App` and `NoctisPro-Tunnel`

Notes:
- The tunnel URL remains live while the tunnel service is running.
- For production with your own domain and a real certificate, set up IIS + win-acme; I can provide an IIS script if needed.