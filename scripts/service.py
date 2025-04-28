from typing import Any, List
from studios.base_studio import BaseStudio

# from studios.base_studio import BaseStudio
from studios.dance_inn import DanceInnStudio
from studios.dna import DnaStudio
from studios.manifest import ManifestStudio
from studios.vins import VinsStudio
from utils.utils import DatabaseManager, ScreenshotManager, retry


def get_studio_list() -> List[BaseStudio]:
    """Get list of all available studios.

    Returns:
        List of studio instances
    """
    return [
        DnaStudio(
            "https://www.yoactiv.com/eventplugin.aspx?Apikey=ZL0C5CwgOJzo38yELwSW%2Fg%3D%3D",
            "dance_n_addiction",
            "https://www.yoactiv.com/Event/",
            max_depth=1,
        ),
        DanceInnStudio(
            "https://danceinn.studio/workshops/upcoming-workshops/",
            "dance.inn.bangalore",
            "https://rzp.io/rzp/",
        ),
        VinsStudio(
            "https://www.vinsdanceco.com/workshops",
            "vins.dance.co",
            "https://www.vinsdanceco.com/events/",
            max_depth=1,
        ),
        ManifestStudio(
            "https://www.yoactiv.com/eventplugin.aspx?Apikey=xwbn1XX+5R9oZfATr4CsLw%3D%3D",
            "manifestbytmn",
            "https://www.yoactiv.com/Event/",
            max_depth=1,
        ),
    ]


@retry(max_attempts=5, backoff_factor=1)
def capture_screenshot(url: str, output_file: str) -> bool:
    """Capture full page screenshot of a URL.

    Args:
        url: Website URL to capture
        output_file: Path to save the screenshot

    Returns:
        True if successful, False otherwise
    """
    service = Service(ChromeDriverManager().install())
    chrome_options = webdriver.ChromeOptions()

    for option in BrowserConfig.CHROME_OPTIONS:
        chrome_options.add_argument(option)

    driver = webdriver.Chrome(service=service, options=chrome_options)
    success = False

    try:
        driver.get(url)
        WebDriverWait(driver, BrowserConfig.PAGE_LOAD_TIMEOUT).until(
            lambda d: d.execute_script("return document.readyState") == "complete"
        )

        total_width = driver.execute_script("return document.body.scrollWidth")
        total_height = driver.execute_script("return document.body.scrollHeight")
        driver.set_window_size(total_width, total_height)

        driver.save_screenshot(output_file)
        success = True
    except Exception as e:
        print(f"Screenshot capture failed: {str(e)}")
        success = False
    finally:
        driver.quit()
        return success
