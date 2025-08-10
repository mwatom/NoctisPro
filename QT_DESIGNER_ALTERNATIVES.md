# PyQt5 Designer Alternatives

Due to dependency conflicts with `pyqt5-tools`, here are alternative ways to get Qt Designer for your PyQt5 development:

## Option 1: System Package Installation (Recommended)
```bash
# For Ubuntu/Debian:
sudo apt update
sudo apt install qttools5-dev-tools

# This installs Qt Designer system-wide
# You can launch it with:
designer
```

## Option 2: Install Qt Creator with Designer
```bash
# Ubuntu/Debian:
sudo apt install qtcreator

# This includes Qt Designer as part of Qt Creator
```

## Option 3: Manual Qt Installation
1. Download Qt from the official website: https://www.qt.io/download
2. Install the complete Qt toolkit which includes Designer
3. Add the Qt bin directory to your PATH

## Option 4: Using PyQt5Designer (if available)
```bash
# This is sometimes available as a separate package:
pip install PyQt5Designer
```

## Option 5: Alternative UI Design Tools
- **Qt Design Studio** - Official Qt tool for UI design
- **GUI Editors** - Various third-party PyQt5 GUI builders
- **Hand-code UI** - Create layouts programmatically

## Current Requirements Status
Your `requirements.txt` now includes only:
```
PyQt5==5.15.9
```

This provides the core PyQt5 functionality without the problematic tool dependencies.

## Verification
To verify PyQt5 works correctly, create a simple test:
```python
import sys
from PyQt5.QtWidgets import QApplication, QWidget, QLabel

app = QApplication(sys.argv)
window = QWidget()
window.setWindowTitle('PyQt5 Test')
window.setGeometry(100, 100, 300, 200)
label = QLabel('PyQt5 is working!', window)
label.move(100, 80)
window.show()
sys.exit(app.exec_())
```