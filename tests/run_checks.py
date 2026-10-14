"""Run all offline QA suites without requiring the Godot executable."""
import subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
suites=[["python","tests/project_preflight.py"],
        ["python","-m","unittest","discover","-s","tests","-p","test_*.py"],
        ["python","-m","unittest","discover","-s","server","-p","test_*.py"],
        ["python","-m","unittest","discover","-s","ai_daily","-p","test_*.py"]]
failed=[]
for command in suites:
 print("\n$", " ".join(command),flush=True)
 r=subprocess.run([sys.executable if x=="python" else x for x in command],cwd=root)
 if r.returncode:failed.append(" ".join(command))
print("\nRESULT:", "PASS" if not failed else "FAIL")
if failed: print("Failed:",*failed,sep="\n")
sys.exit(bool(failed))
