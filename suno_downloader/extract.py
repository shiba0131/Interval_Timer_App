from curl_cffi import requests
import re

def find_endpoints():
    url = "https://suno.com"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    try:
        response = requests.get(url, headers=headers, impersonate="chrome110")
        html = response.text
        # Find any absolute URL containing "api" and "suno"
        api_urls = re.findall(r'https://[^"\']*suno[^"\']*api[^"\']*', html)
        print("API URLs found in HTML:", set(api_urls))
        
        js_files = re.findall(r'src="([^"]+\.js)"', html)
        for js in js_files[:20]:
            js_url = js if js.startswith("http") else f"https://suno.com{js}"
            try:
                js_resp = requests.get(js_url, headers=headers, impersonate="chrome110")
                api_urls = re.findall(r'https://[a-zA-Z0-9.-]*suno[a-zA-Z0-9.-]*/[a-zA-Z0-9./-]*', js_resp.text)
                filtered = [u for u in api_urls if 'api' in u or 'feed' in u or 'library' in u]
                if filtered:
                    print(f"URLs in {js}:", set(filtered))
            except:
                pass
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    find_endpoints()
