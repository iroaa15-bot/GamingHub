from pathlib import Path
p=Path(__file__).resolve().parents[1]/"scripts/ad_manager.gd"
s=p.read_text()
for required in ["func report_rewarded_failed", "request_id != pending_request_id", "func confirm_native_reward", "completed_request_ids[request_id] = true", "func cancel_pending_request", "production_ads_enabled\": false", "func request_interstitial_ad"]:
 assert required in s, required
print("PASS: static state-machine safety checks (not a device/SDK test)")
