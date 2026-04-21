import os
import re
from curl_cffi import requests
import time

# ==============================================================================
# 設定
# ==============================================================================

# Suno AIのCookieを設定してください
# ブラウザの開発者ツール (F12) -> Networkタブ -> 任意の通信のRequest Headersから "cookie:" の値をコピー
SUNO_COOKIE = "_gcl_au=1.1.156640449.1776427197; _twpid=tw.1776427197515.286654707165615792; _ga=GA1.1.764504601.1776427198; singular_device_id=de434bc1-e2b3-430e-ace3-0a557319b2e8; ajs_anonymous_id=0589c22e-cda3-440c-8586-c017ee104fc8; _fbp=fb.1.1776427198560.554935687239825480; _tt_enable_cookie=1; _ttp=01KPDMZT60B5JX25HC6GRAQ45V_.tt.1; sessionid=1sux4w3lwlye0jutv3y7nmoqtrxpxrjt; __client_uat=1776427514; __client_uat_Jnxw-muT=1776427514; __stripe_mid=239445d7-9ce4-4ec6-86d3-9cc4a9ad40a99e0e0f; OptanonAlertBoxClosed=2026-04-17T12:10:22.508Z; _clck=675t5o%5E2%5Eg5c%5E0%5E2298; __session=eyJhbGciOiJSUzI1NiIsImtpZCI6InN1bm8tYXBpLXJzMjU2LWtleS0xIiwidHlwIjoiSldUIn0.eyJzdW5vLmNvbS9jbGFpbXMvdXNlcl9pZCI6IjJlMzc2OWMxLTdkY2EtNDE2My1hMDdmLWU2OTU2ZDZiOTQ0OCIsImh0dHBzOi8vc3Vuby5haS9jbGFpbXMvY2xlcmtfaWQiOiIyZTM3NjljMS03ZGNhLTQxNjMtYTA3Zi1lNjk1NmQ2Yjk0NDgiLCJzdW5vLmNvbS9jbGFpbXMvdG9rZW5fdHlwZSI6ImFjY2VzcyIsInN1bm8vZGlkIjoxMTExNzI3NzIsImV4cCI6MTc3NjYzOTcyOSwiYXVkIjoic3Vuby1hcGkiLCJzdWIiOiIyZTM3NjljMS03ZGNhLTQxNjMtYTA3Zi1lNjk1NmQ2Yjk0NDgiLCJhenAiOiJodHRwczovL3N1bm8uY29tIiwiZnZhIjpbMCwtMV0sImlhdCI6MTc3NjYzNjEyOSwiaXNzIjoiaHR0cHM6Ly9hdXRoLnN1bm8uY29tIiwiaml0IjoiODk1ODJjOWEtMTM4Zi00YmNlLTlmNGUtZWFkM2EyMDU2Yjc5Iiwic3Vuby5jb20vY2xhaW1zL2VtYWlsIjoicGlucG9uMDEzMUBnbWFpbC5jb20iLCJodHRwczovL3N1bm8uYWkvY2xhaW1zL2VtYWlsIjoicGlucG9uMDEzMUBnbWFpbC5jb20iLCJzdW5vL2hhbmRsZSI6InNoaWJhMDEzMSIsInN1bm8vdXNlcl9pZCI6IjE0MTg2OTUzNyIsInN1bm8vdXNlcm5hbWUiOiJwaW5wb24wMTMxQGdtYWlsLmNvbSJ9.OJ6CSQsDsYus-jjRisYE0lEzw1rcUxUgxeeVGOFAyJxoML25mbzHpXioiJObr-BFrGbanmoYdkBGVmdAKX7RMbSjw-tTOniqeqQrlPNuvN2oJGWRu4TfBGQUNhFA5EMjbLtnDfCx_dGwuNyuwhGlvLVbeCw13Eu_wLXg8gRLOEjjNo7z2cXsQ4FrUV9Ogpd-7YqFtABEqSxJ2T9i1AWIhQ4FXK2rQTdko3F38Z9OPy7G_xmrteqrNWjtmYY_onNzIIMIqsuE-hmQGkNvOFS-QEUJCLwEDPJlHyePiVfgI1AXC0JzkGPHf9_90BJsvpCA3PA5xTXbLHjhHjveQZydqQ; IR_gbd=suno.com; IR_46384=1776636130484%7C0%7C1776636130484%7C%7C; __client=eyJhbGciOiJSUzI1NiIsImtpZCI6InN1bm8tYXBpLXJzMjU2LWtleS0xIiwidHlwIjoiSldUIn0.eyJzdW5vLmNvbS9jbGFpbXMvY2xpZW50X2lkIjoiY2xpZW50X1MzTW04TTRVUjdmdHJrcVRBNjd0ZXoiLCJzdW5vLmNvbS9jbGFpbXMvdG9rZW5fdHlwZSI6InJlZnJlc2giLCJpc3MiOiJodHRwczovL2F1dGguc3Vuby5jb20iLCJleHAiOjE4MDgxNzIxMzF9.urgyLsN0x6YX6iQPPcoxf2NdcU23kPFo484V8Em6-p6shihOtH-RZzqg762QLpLvwsAC-rxobuFrD1oOL664aDkTaHg9J_9BDA1t-9o9_aD3eR5N4Wxg1ZRy7CIvX_Mmir0eup7H007qYNeGYcBO9gd9tOXp-lKZLzJtpL_agzJE8RpEO6B4Z0qI8HhUFSQsGJt3pVl7J-yxPvlH_GpylMTlRDQtACSs8JXsbZ8WUJqoZw7yFm6e9Xm2X3mJIvQnR5vm6oTqGEuvedzWWCZaRiS3KRZVNddVhiCVT7zJLKpC4tNXnLm8_k4qwnwJWqFlCMV9hPFqJY6FKiOqCMNInw; __client_Jnxw-muT=eyJhbGciOiJSUzI1NiIsImtpZCI6InN1bm8tYXBpLXJzMjU2LWtleS0xIiwidHlwIjoiSldUIn0.eyJzdW5vLmNvbS9jbGFpbXMvY2xpZW50X2lkIjoiY2xpZW50X1MzTW04TTRVUjdmdHJrcVRBNjd0ZXoiLCJzdW5vLmNvbS9jbGFpbXMvdG9rZW5fdHlwZSI6InJlZnJlc2giLCJpc3MiOiJodHRwczovL2F1dGguc3Vuby5jb20iLCJleHAiOjE4MDgxNzIxMzF9.urgyLsN0x6YX6iQPPcoxf2NdcU23kPFo484V8Em6-p6shihOtH-RZzqg762QLpLvwsAC-rxobuFrD1oOL664aDkTaHg9J_9BDA1t-9o9_aD3eR5N4Wxg1ZRy7CIvX_Mmir0eup7H007qYNeGYcBO9gd9tOXp-lKZLzJtpL_agzJE8RpEO6B4Z0qI8HhUFSQsGJt3pVl7J-yxPvlH_GpylMTlRDQtACSs8JXsbZ8WUJqoZw7yFm6e9Xm2X3mJIvQnR5vm6oTqGEuvedzWWCZaRiS3KRZVNddVhiCVT7zJLKpC4tNXnLm8_k4qwnwJWqFlCMV9hPFqJY6FKiOqCMNInw; OptanonConsent=isGpcEnabled=0&datestamp=Mon+Apr+20+2026+07%3A02%3A11+GMT%2B0900+(%E6%97%A5%E6%9C%AC%E6%A8%99%E6%BA%96%E6%99%82)&version=202601.2.0&browserGpcFlag=0&isIABGlobal=false&hosts=&consentId=4b014670-68b5-41f3-85a5-48f6b454a144&interactionCount=2&isAnonUser=1&prevHadToken=0&landingPath=NotLandingPage&groups=C0001%3A1%2CC0002%3A1%2CC0003%3A1%2CC0004%3A1%2CBG5%3A1&crTime=1776427822971&intType=1&geolocation=JP%3B13&AwaitingReconsent=false; ab.storage.sessionId.b67099e5-3183-4de8-8f8f-fdea9ac93d15=g%3Afa20fb65-7e2d-4cc9-b937-efd87c0c6a42%7Ce%3A1776637931741%7Cc%3A1776636131741%7Cl%3A1776636131741; ab.storage.deviceId.b67099e5-3183-4de8-8f8f-fdea9ac93d15=g%3Ad0417b9a-11a6-4701-9de4-419b1ae44d78%7Ce%3Aundefined%7Cc%3A1776427519479%7Cl%3A1776636131742; ab.storage.userId.b67099e5-3183-4de8-8f8f-fdea9ac93d15=g%3A2e3769c1-7dca-4163-a07f-e6956d6b9448%7Ce%3Aundefined%7Cc%3A1776427519476%7Cl%3A1776636131742; t-ip=1; _uetsid=e821f0f03bd711f186c2594e6b4d36cd|3kczze|2|g5c|0|2300; _uetvid=f4e345103a5411f182ac474899a343ba|1wo88g0|1776636132540|1|1|bat.bing.com/p/conversions/c/j; prelude_dispatch_id=019da7c3-f75e-7500-96c1-cfef414ad49c; _clsk=rnfeh1%5E1776636132765%5E1%5E0%5Ej.clarity.ms%2Fcollect; __stripe_sid=eaf608d2-4ff7-4c70-9f5c-70f3fad37320d439cf; ttcsid=1776636131956::rDQbGCGavqoNOdIpzz1s.11.1776636141963.0::1.-3974.0::0.0.0.0::0.0.0; ttcsid_CT67HURC77UB52N3JFBG=1776636131956::Ik4c9Lv89903YrRyBEtb.11.1776636141964.1; _ga_7B0KEDD7XP=GS2.1.s1776636130$o10$g1$t1776636149$j41$l0$h0$d1vLUB5anTv4Z-DeAFqrmSvipN8Q_cLlWzg; tatari-session-cookie=2d66b4e1-05dc-a414-ad1c-9c1c2def0ab5"

# ダウンロードしたい曲数（今回は30曲）
DOWNLOAD_LIMIT = 30

# ダウンロード先のフォルダ
DOWNLOAD_DIR = "suno_downloads"

# ==============================================================================

def get_suno_feed(cookie, page=0):
    """Suno APIから曲のフィード（一覧）を取得します"""
    url = f"https://studio-api-prod.suno.com/api/feed/?page={page}"
    
    headers = {
        "Cookie": cookie,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://suno.com/",
        "Origin": "https://suno.com"
    }
    
    # CookieからJWTセッショントークンを抽出してAuthorizationヘッダーに追加
    match = re.search(r'__session=([^;]+)', cookie)
    if match:
        headers["Authorization"] = f"Bearer {match.group(1)}"
    
    try:
        response = requests.get(url, headers=headers, impersonate="chrome110")
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Suno APIからのデータ取得に失敗しました: {e}")
        return None

def download_audio(url, filename):
    """指定されたURLからオーディオファイルをダウンロードします"""
    try:
        response = requests.get(url, stream=True, impersonate="chrome110")
        response.raise_for_status()
        with open(filename, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return True
    except Exception as e:
        print(f"\nダウンロード失敗 ({filename}): {e}")
        return False

def main():
    print("Suno AI 自動ダウンローダー")
    print("-" * 30)
    

    if not os.path.exists(DOWNLOAD_DIR):
        os.makedirs(DOWNLOAD_DIR)
        print(f"'{DOWNLOAD_DIR}' フォルダを作成しました。")

    print(f"Suno AIから {DOWNLOAD_LIMIT} 曲のダウンロードを開始します...\n")
    
    downloaded_count = 0
    page = 0
    
    while downloaded_count < DOWNLOAD_LIMIT:
        print(f"ページ {page} の曲データを取得中...")
        songs = get_suno_feed(SUNO_COOKIE, page)
        
        if not songs:
            print("これ以上の曲データが見つかりませんでした。もしくはCookieが無効です。")
            break
            
        for song in songs:
            if downloaded_count >= DOWNLOAD_LIMIT:
                break
                
            # 曲情報からタイトルとオーディオURLを取得
            song_id = song.get("id", "unknown_id")
            title = song.get("title") or "Untitled"
            
            # ファイル名に使えない文字を置換
            safe_title = "".join(c for c in title if c.isalnum() or c in " -_ぁ-んァ-ン一-龥").strip()
            if not safe_title:
                safe_title = "Untitled"
                
            # オーディオURLの取得
            audio_url = song.get("audio_url")
            
            if not audio_url:
                print(f"  [-] スキップ: '{title}' (オーディオURLが見つかりません。生成中の可能性があります)")
                continue
                
            filename = os.path.join(DOWNLOAD_DIR, f"{safe_title}_{song_id}.mp3")
            
            if os.path.exists(filename):
                print(f"  [*] スキップ: '{title}' (既にダウンロード済みです)")
                downloaded_count += 1
                continue
                
            print(f"  [{downloaded_count + 1}/{DOWNLOAD_LIMIT}] ダウンロード中: {title} ... ", end="", flush=True)
            if download_audio(audio_url, filename):
                print("OK")
                downloaded_count += 1
                
            # サーバーに負荷をかけないように待機
            time.sleep(1.5)
            
        page += 1
        
    print(f"\n完了しました！ 合計 {downloaded_count} 曲が '{DOWNLOAD_DIR}' フォルダに保存されました。")

if __name__ == "__main__":
    main()
