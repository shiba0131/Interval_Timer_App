from curl_cffi import requests

def test_api():
    urls = [
        "https://api.suno.ai/api/feed/",
        "https://studio-api.suno.ai/api/feed",
        "https://api.suno.ai/",
        "https://clerk.suno.com/v1/client"
    ]
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    
    for url in urls:
        print(f"\nTesting {url} ...")
        try:
            response = requests.get(url, headers=headers, impersonate="chrome110")
            print(response.status_code)
            if response.status_code == 200:
                print("SUCCESS!")
                print(response.text[:200])
            else:
                print("FAILED:", response.text[:100])
        except Exception as e:
            print("EXCEPTION:", e)

if __name__ == "__main__":
    test_api()
