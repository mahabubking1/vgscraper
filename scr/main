from __future__ import annotations
import os
import time
import random
import re
import traceback
from typing import Optional, Dict, Any, List

from apify import Actor
import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys

DEVICE_PRESETS = {
    "iphone_13": {
        "ua": "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1",
        "width": 390, "height": 844, "pixel_ratio": 3.0
    },
    "iphone_14": {
        "ua": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/16A366 Safari/604.1",
        "width": 393, "height": 852, "pixel_ratio": 3.0
    },
    "pixel_7": {
        "ua": "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "width": 1080, "height": 2400, "pixel_ratio": 2.5
    }
}

def human_sleep(a=0.35, b=1.1):
    time.sleep(random.uniform(a, b))

def build_apify_proxy(password: str, groups: str = "RESIDENTIAL", country: Optional[str] = "US", session: Optional[str] = None) -> str:
    if not password:
        raise ValueError("APIFY proxy password missing. Add Actor secret 'APIFY_PROXY_PASSWORD'.")
    parts = f"groups-{groups}"
    if country:
        parts += f"-country-{country}"
    url = f"http://{parts}:{password}@proxy.apify.com:8000"
    if session:
        url += f"?session={session}"
    return url

def choose_device(pool: Optional[List[str]], rotate: bool) -> Dict[str, Any]:
    if not pool:
        pool = list(DEVICE_PRESETS.keys())
    name = random.choice(pool) if rotate else pool[0]
    return DEVICE_PRESETS.get(name, DEVICE_PRESETS["iphone_13"])

def extract_balance_text(html: str) -> Optional[str]:
    m = re.search(r"\$\s*\d{1,6}(?:[.,]\d{1,2})?", html)
    return m.group(0) if m else None

def try_fill(driver, selectors: List[str], value: str) -> bool:
    for sel in selectors:
        try:
            els = driver.find_elements(By.CSS_SELECTOR, sel)
            if not els:
                continue
            el = els[0]
            try:
                el.clear()
            except Exception:
                pass
            for ch in str(value):
                el.send_keys(ch)
                time.sleep(random.uniform(0.02, 0.08))
            return True
        except Exception:
            continue
    return False

def run_one_attempt(attempt: int, cfg: Dict[str, Any]) -> Dict[str, Any]:
    url = cfg["url"]
    card_number = cfg.get("card_number", "")
    exp_month = cfg.get("exp_month", "")
    exp_year = cfg.get("exp_year", "")
    cvv = cfg.get("cvv", "")
    rotate_devices = bool(cfg.get("rotate_devices", True))
    device_pool = cfg.get("device_pool", list(DEVICE_PRESETS.keys()))
    take_screenshot = bool(cfg.get("take_screenshot", True))
    push_html_snapshot = bool(cfg.get("push_html_snapshot", True))

    device = choose_device(device_pool, rotate_devices)
    Actor.log.info(f"🎭 Attempt {attempt}: using device {device}")

    proxy_url = None
    if cfg.get("use_apify_proxy", True):
        pwd = cfg.get("apify_proxy_password") or os.environ.get("APIFY_PROXY_PASSWORD")
        session = None
        sess_list = cfg.get("apify_proxy_sessions", [])
        if isinstance(sess_list, list) and len(sess_list) >= attempt:
            session = sess_list[attempt - 1]
        proxy_url = build_apify_proxy(
            password=pwd,
            groups=cfg.get("apify_proxy_groups", "RESIDENTIAL"),
            country=cfg.get("apify_proxy_country", "US"),
            session=session,
        )
        Actor.log.info(f"🌐 Proxy set (session {session if session else 'none'})")

    opts = uc.ChromeOptions()
    opts.headless = False
    mobile = {
        "deviceMetrics": {"width": device["width"], "height": device["height"], "pixelRatio": device["pixel_ratio"]},
        "userAgent": device["ua"],
    }
    opts.add_experimental_option("mobileEmulation", mobile)
    opts.add_argument(f'--user-agent={device["ua"]}')
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--disable-blink-features=AutomationControlled")
    if proxy_url:
        opts.add_argument(f"--proxy-server={proxy_url}")

    driver = None
    out = {"attempt": attempt, "status": "unknown", "device": device}
    try:
        Actor.log.info("🚀 Launching undetected Chrome...")
        driver = uc.Chrome(options=opts, use_subprocess=True)
        try:
            driver.execute_cdp_cmd("Page.addScriptToEvaluateOnNewDocument", {"source": """
                Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
                window.navigator.chrome = { runtime: {} };
                Object.defineProperty(navigator, 'plugins', { get: () => [1,2,3,4,5] });
                Object.defineProperty(navigator, 'languages', { get: () => ['en-US','en'] });
            """})
        except Exception:
            pass

        driver.set_page_load_timeout(120)
        Actor.log.info(f"🌍 Navigating to {url} ...")
        driver.get(url)
        human_sleep(1.2, 2.4)

        html = driver.page_source or ""
        if push_html_snapshot:
            Actor.push_data({"stage": f"attempt_{attempt}_after_nav", "html_snapshot": html[:20000]})

        if "_Incapsula_Resource" in html or "incapsula" in html.lower() or "captcha" in html.lower():
            Actor.log.warning("🚫 Blocked after nav (Incapsula/CAPTCHA).")
            out["status"] = "blocked_initial"
            return out

        for _ in range(2 + random.randint(0, 2)):
            driver.execute_script("window.scrollBy(0, Math.floor(Math.random()*120)+40);")
            human_sleep(0.25, 0.8)

        filled_card = try_fill(driver, ["#cardnumber", "#CardNumber", "input[name='cardnumber']", "input[name='CardNumber']"], card_number)
        if filled_card:
            try_fill(driver, ["#expMonth", "#ExpirationMonth", "select[name='expMonth']", "input[name='expMonth']"], exp_month)
            try_fill(driver, ["#expirationYear", "#ExpirationYear", "select[name='expYear']", "input[name='expYear']"], exp_year)
            try_fill(driver, ["#cvv", "#SecurityCode", "input[name='cvv']", "input[name='securitycode']"], cvv)

            clicked = False
            for sel in ["#brandLoginForm_button", "#btnSubmit", "button[type='submit']", "input[type='submit']"]:
                try:
                    els = driver.find_elements(By.CSS_SELECTOR, sel)
                    if els:
                        els[0].click()
                        clicked = True
                        break
                except Exception:
                    continue
            if not clicked:
                try:
                    el = driver.find_element(By.CSS_SELECTOR, "#cardnumber")
                    el.send_keys(Keys.RETURN)
                except Exception:
                    pass

            human_sleep(2.0, 4.0)

        html2 = driver.page_source or ""
        if push_html_snapshot:
            Actor.push_data({"stage": f"attempt_{attempt}_after_submit", "html_snapshot": html2[:20000]})

        bal = None
        try:
            els = driver.find_elements(By.CSS_SELECTOR, ".balance-container, #Balance, .result")
            if els:
                bal = els[0].text.strip()
        except Exception:
            pass
        if not bal:
            bal = extract_balance_text(html2)

        out["status"] = "success_found" if bal else "no_balance_found"
        out["balance_text"] = bal

        if cfg.get("take_screenshot", True):
            shot = f"/tmp/screenshot_attempt_{attempt}.png"
            try:
                driver.save_screenshot(shot)
                out["screenshot"] = shot
            except Exception:
                pass

        return out
    except Exception as e:
        out["status"] = "fatal_error"
        out["error"] = f"{type(e).__name__}: {e}"
        Actor.log.error(f"🔥 Fatal attempt {attempt}: {e}\n{traceback.format_exc()}")
        try:
            out["html_snapshot"] = (driver.page_source or "")[:20000]
        except Exception:
            pass
        return out
    finally:
        try:
            if driver:
                driver.quit()
        except Exception:
            pass

async def main() -> None:
    async with Actor:
        inp = await Actor.get_input() or {}
        cfg = {
            "url": inp.get("url", "https://balance.vanillagift.com"),
            "card_number": inp.get("card_number", ""),
            "exp_month": inp.get("exp_month", ""),
            "exp_year": inp.get("exp_year", ""),
            "cvv": inp.get("cvv", ""),
            "max_attempts": int(inp.get("max_attempts", 3)),
            "use_apify_proxy": bool(inp.get("use_apify_proxy", True)),
            "apify_proxy_password": inp.get("apify_proxy_password") or os.environ.get("APIFY_PROXY_PASSWORD"),
            "apify_proxy_groups": inp.get("apify_proxy_groups", "RESIDENTIAL"),
            "apify_proxy_country": inp.get("apify_proxy_country", "US"),
            "rotate_devices": bool(inp.get("rotate_devices", True)),
            "device_pool": inp.get("device_pool", list(DEVICE_PRESETS.keys())),
            "apify_proxy_sessions": inp.get("apify_proxy_sessions", []),
            "take_screenshot": bool(inp.get("take_screenshot", True)),
            "push_html_snapshot": bool(inp.get("push_html_snapshot", True)),
        }
        Actor.log.info("🎬 Config: " + str({k: ('***' if k=='apify_proxy_password' and v else v) for k,v in cfg.items()}))

        attempts = cfg["max_attempts"]
        final = None
        for i in range(1, attempts + 1):
            res = run_one_attempt(i, cfg)
            await Actor.push_data({"attempt": i, "result": res})
            Actor.log.info(f"✅ Attempt {i}/{attempts} → {res.get('status')}")
            final = res
            if res.get("status") == "success_found":
                break
            time.sleep(min(2 ** i, 8))

        out = {
            "url": cfg["url"],
            "attempts": attempts,
            "final_status": final.get("status") if final else "no_result",
            "final_result": final,
            "timestamp": int(time.time())
        }
        await Actor.push_data(out)
        Actor.log.info("🏁 Actor finished.")
