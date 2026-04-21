import asyncio
from playwright.async_api import async_playwright

async def capture_network():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        )
        page = await context.new_page()

        endpoints = set()

        page.on("request", lambda request: endpoints.add(request.url))

        print("Navigating to suno.com...")
        try:
            await page.goto("https://suno.com/", timeout=15000)
            await page.wait_for_timeout(3000)
        except Exception as e:
            print("Navigation exception:", e)
        
        print("\nCaptured URLs containing 'api', 'feed', or 'studio':")
        for url in endpoints:
            if 'api' in url or 'feed' in url or 'studio' in url:
                print(url)
                
        await browser.close()

if __name__ == "__main__":
    asyncio.run(capture_network())
