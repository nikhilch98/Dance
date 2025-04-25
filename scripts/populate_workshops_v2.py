import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.utils import ScreenshotManager
from scripts.service import get_studio_list
from pprint import pprint

def get_screenshot_path(studio_id, link: str) -> str:
    screenshot_path = f"screenshots/{studio_id}_{link.split('/')[-1]}.png"
    return screenshot_path

def main():
    studios = get_studio_list()
    
    for studio in studios:
        errors = []
        studio_id = studio.config.studio_id
        print(f"\nProcessing Studio {studio_id}")

        # Step 1 - Scrape all the event links from the studio website
        links = studio.scrape_links()
        print("Extracted Links")
        
        for ind, link in enumerate(links):
            # Step 2.1 - Capture Screenshot of the link
            print(f"Extracting Screenshot {ind+1}/{len(links)}")
            screenshot_path = get_screenshot_path(link, studio_id)
            # Screenshot will be captured at screenshots/ folder
            if not ScreenshotManager.capture_screenshot(link, screenshot_path):
                errors.append((studio_id, link, "Error in capturing screenshot"))
                continue        
        pprint(errors)
        break
            
            
        
        
    

if __name__ == "__main__":
    main()