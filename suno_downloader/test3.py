from curl_cffi import requests
import re

def get_session_token(cookie_string):
    match = re.search(r'__session=([^;]+)', cookie_string)
    if match:
        return match.group(1)
    return None

def test_api():
    cookie = "_gcl_au=1.1.156640449.1776427197; _twpid=tw.1776427197515.286654707165615792; _ga=GA1.1.764504601.1776427198; singular_device_id=de434bc1-e2b3-430e-ace3-0a557319b2e8; ajs_anonymous_id=0589c22e-cda3-440c-8586-c017ee104fc8; _fbp=fb.1.1776427198560.554935687239825480; _tt_enable_cookie=1; _ttp=01KPDMZT60B5JX25HC6GRAQ45V_.tt.1; sessionid=1sux4w3lwlye0jutv3y7nmoqtrxpxrjt; __client_uat=1776427514; __client_uat_Jnxw-muT=1776427514; __stripe_mid=239445d7-9ce4-4ec6-86d3-9cc4a9ad40a99e0e0f; OptanonAlertBoxClosed=2026-04-17T12:10:22.508Z; _clck=675t5o%5E2%5Eg5c%5E0%5E2298; IR_gbd=suno.com; ab.storage.deviceId.b67099e5-3183-4de8-8f8f-fdea9ac93d15=g%3Ad0417b9a-11a6-4701-9de4-419b1ae44d78%7Ce%3Aundefined%7Cc%3A1776427519479%7Cl%3A1776614251216; ab.storage.userId.b67099e5-3183-4de8-8f8f-fdea9ac93d15=g%3A2e3769c1-7dca-4163-a07f-e6956d6b9448%7Ce%3Aundefined%7Cc%3A1776427519476%7Cl%3A1776614251217; __session=eyJhbGciOiJSUzI1NiIsImtpZCI6InN1bm8tYXBpLXJzMjU2LWtleS0xIiwidHlwIjoiSldUIn0.eyJzdW5vLmNvbS9jbGFpbXMvdXNlcl9pZCI6IjJlMzc2OWMxLTdkY2EtNDE2My1hMDdmLWU2OTU2ZDZiOTQ0OCIsImh0dHBzOi8vc3Vuby5haS9jbGFpbXMvY2xlcmtfaWQiOiIyZTM3NjljMS03ZGNhLTQxNjMtYTA3Zi1lNjk1NmQ2Yjk0NDgiLCJzdW5vLmNvbS9jbGFpbXMvdG9rZW5fdHlwZSI6ImFjY2VzcyIsInN1bm8vZGlkIjoxMTExNzI3NzIsImV4cCI6MTc3NjYyMDcyNiwiYXVkIjoic3Vuby1hcGkiLCJzdWIiOiIyZTM3NjljMS03ZGNhLTQxNjMtYTA3Zi1lNjk1NmQ2Yjk0NDgiLCJhenAiOiJodHRwczovL3N1bm8uY29tIiwiZnZhIjpbMCwtMV0sImlhdCI6MTc3NjYxNzEyNiwiaXNzIjoiaHR0cHM6Ly9hdXRoLnN1bm8uY29tIiwiaml0IjoiNjY0ZTcxZTktNzE2YS00OGUwLTk2MGEtOTA2YWFhODg5ZjJmIiwic3Vuby5jb20vY2xhaW1zL2VtYWlsIjoicGlucG9uMDEzMUBnbWFpbC5jb20iLCJodHRwczovL3N1bm8uYWkvY2xhaW1zL2VtYWlsIjoicGlucG9uMDEzMUBnbWFpbC5jb20iLCJzdW5vL2hhbmRsZSI6InNoaWJhMDEzMSIsInN1bm8vdXNlcl9pZCI6IjE0MTg2OTUzNyIsInN1bm8vdXNlcm5hbWUiOiJwaW5wb24wMTMxQGdtYWlsLmNvbSJ9.rFXPW-Ae5p1E5P3_BH74gUPZOEHnqG7tbJUzHgXDxurhiRojppIZFfTlQY57D0g8t8-3VK8S3uAR9150Iq3F3zgFL-l7qVZQuHG1q3jb8EpXSCTB3z23K2eqXTTVnicqHtbl9zonsf-IWDDub5wVKw313Ysvswsy6K9a5ApmDz6B7PB0Gw7v3HluXZs7bUlZbtrmSL1IPTqeGlLb_Cc8isd_6RTiywONpwJN-5yte8-gT2GbQGBTP9AiiIgP0FHXNZbHDsBSxrHOxgKmgXRC96pbH2-s-JUxWlh2pNqHNEOMbJBKr1cLaM3pglDpJbKBbjt7V9plqDrseN-yS8jpCA; IR_46384=1776617127586%7C0%7C1776617127586%7C%7C; __client=eyJhbGciOiJSUzI1NiIsImtpZCI6InN1bm8tYXBpLXJzMjU2LWtleS0xIiwidHlwIjoiSldUIn0.eyJzdW5vLmNvbS9jbGFpbXMvY2xpZW50X2lkIjoiY2xpZW50X1MzTW04TTRVUjdmdHJrcVRBNjd0ZXoiLCJzdW5vLmNvbS9jbGFpbXMvdG9rZW5fdHlwZSI6InJlZnJlc2giLCJpc3MiOiJodHRwczovL2F1dGguc3Vuby5jb20iLCJleHAiOjE4MDgxNTMxMjh9.twn_xYhzbqs15HisaO8U3sbBT60nXeVNQn0CTqjJMXJHPFuCKjGBu5BwqyhV4RtqpTLo189pkFS3yXRlfvAdvHpuYLbk_ew7BQGy5MP8GPqmTl4YaPyHMDQBSa6C2f0WZSUt1zzIh1ng-V9lTiaqDqJscNLYLsKJn3OzdIQan37hZefLPcM2_bcAl_HFGkeeY3sh4I_0OPNhtQaamjSGbSmoipBG-aN2m_WUb6fc86XD4pLF_m-_6WMYU1QQJKQDV1W74IUFbzFavZbxDRUbWNiMTNi-wWM6fRmnGNbnTxGhIVFzuOxD2vVugk94Qb-ywenpDpcXuMVCwFIRd2Fp-g; __client_Jnxw-muT=eyJhbGciOiJSUzI1NiIsImtpZCI6InN1bm8tYXBpLXJzMjU2LWtleS0xIiwidHlwIjoiSldUIn0.eyJzdW5vLmNvbS9jbGFpbXMvY2xpZW50X2lkIjoiY2xpZW50X1MzTW04TTRVUjdmdHJrcVRBNjd0ZXoiLCJzdW5vLmNvbS9jbGFpbXMvdG9rZW5fdHlwZSI6InJlZnJlc2giLCJpc3MiOiJodHRwczovL2F1dGguc3Vuby5jb20iLCJleHAiOjE4MDgxNTMxMjh9.twn_xYhzbqs15HisaO8U3sbBT60nXeVNQn0CTqjJMXJHPFuCKjGBu5BwqyhV4RtqpTLo189pkFS3yXRlfvAdvHpuYLbk_ew7BQGy5MP8GPqmTl4YaPyHMDQBSa6C2f0WZSUt1zzIh1ng-V9lTiaqDqJscNLYLsKJn3OzdIQan37hZefLPcM2_bcAl_HFGkeeY3sh4I_0OPNhtQaamjSGbSmoipBG-aN2m_WUb6fc86XD4pLF_m-_6WMYU1QQJKQDV1W74IUFbzFavZbxDRUbWNiMTNi-wWM6fRmnGNbnTxGhIVFzuOxD2vVugk94Qb-ywenpDpcXuMVCwFIRd2Fp-g; ab.storage.sessionId.b67099e5-3183-4de8-8f8f-fdea9ac93d15=g%3Aad8b34b0-e7db-4e9d-99d6-dd932370c96b%7Ce%3A1776618928181%7Cc%3A1776614251215%7Cl%3A1776617128181; OptanonConsent=isGpcEnabled=0&datestamp=Mon+Apr+20+2026+01%3A45%3A28+GMT%2B0900+(%E6%97%A5%E6%9C%AC%E6%A8%99%E6%BA%96%E6%99%82)&version=202601.2.0&browserGpcFlag=0&isIABGlobal=false&hosts=&consentId=4b014670-68b5-41f3-85a5-48f6b454a144&interactionCount=2&isAnonUser=1&prevHadToken=0&landingPath=NotLandingPage&groups=C0001%3A1%2CC0002%3A1%2CC0003%3A1%2CC0004%3A1%2CBG5%3A1&crTime=1776427822971&intType=1&geolocation=JP%3B13&AwaitingReconsent=false; t-ip=1; tatari-session-cookie=2d66b4e1-05dc-a414-ad1c-9c1c2def0ab5; _uetsid=e821f0f03bd711f186c2594e6b4d36cd|3kczze|2|g5c|0|2300; ttcsid=1776617128405::f7xPqsud4sh9_63VcUu4.10.1776617128626.0::1.-2632.0::0.0.0.0::0.0.0; ttcsid_CT67HURC77UB52N3JFBG=1776617128404::in0qN2RZuzp8hcEWf80f.10.1776617128626.0; prelude_dispatch_id=019da6a2-0150-7d70-a128-56598b2c1fba; __stripe_sid=373fefe8-e675-4532-8023-8d65eaac71427acda3; _clsk=1t6m2u6%5E1776617137971%5E3%5E0%5Ej.clarity.ms%2Fcollect; _uetvid=f4e345103a5411f182ac474899a343ba|1ffzh4t|1776617138055|3|1|bat.bing.com/p/conversions/c/j; _ga_7B0KEDD7XP=GS2.1.s1776617127$o9$g1$t1776617162$j25$l0$h0$d1vLUB5anTv4Z-DeAFqrmSvipN8Q_cLlWzg"
    token = get_session_token(cookie)
    headers = {
        "Cookie": cookie,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://suno.com/",
        "Origin": "https://suno.com",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    
    url = "https://studio-api-prod.suno.com/api/feed/?page=0"
    print(f"\nTesting {url} ...")
    try:
        response = requests.get(url, headers=headers, impersonate="chrome110")
        print(response.status_code)
        if response.status_code == 200:
            print("SUCCESS!")
            # print(response.text[:200])
        else:
            print("FAILED:", response.text[:200])
    except Exception as e:
        print("EXCEPTION:", e)

if __name__ == "__main__":
    test_api()
