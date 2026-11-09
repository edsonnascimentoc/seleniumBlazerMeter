"""Teste funcional remoto do console VMware ESXi via Selenium Grid 4."""

import time
import unittest

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


class TestESXiNavigation(unittest.TestCase):
    def setUp(self):
        options = Options()
        options.add_argument("--headless=new")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu")
        options.add_argument("--blink-settings=imagesEnabled=false")
        options.add_argument("--ignore-certificate-errors")
        options.add_argument("--disable-renderer-backgrounding")
        options.add_argument("--disable-background-timer-throttling")

        options.accept_insecure_certs = True
        options.page_load_strategy = "eager"

        self.driver = webdriver.Remote(
            command_executor="http://127.0.0.1:4444",
            options=options,
        )
        self.driver.set_page_load_timeout(45)

    def test_access_esxi(self):
        target_url = "https://10.1.100.102/ui/"

        self.driver.get(target_url)

        wait = WebDriverWait(self.driver, 15)
        wait.until(
            EC.presence_of_element_located((By.TAG_NAME, "body"))
        )

        # Preservado da versão operacional homologada.
        time.sleep(1)

        self.assertIn("VMware", self.driver.page_source)

    def tearDown(self):
        driver = getattr(self, "driver", None)
        if driver is not None:
            driver.quit()


if __name__ == "__main__":
    unittest.main()
