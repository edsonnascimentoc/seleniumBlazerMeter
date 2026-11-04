"""Teste funcional remoto do console VMware ESXi via Selenium Grid 4."""
import unittest

from selenium import webdriver
from selenium.webdriver.chrome.options import Options


class TestESXiNavigation(unittest.TestCase):
    def setUp(self):
        options = Options()
        options.add_argument("--headless=new")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--ignore-certificate-errors")
        options.add_argument("--blink-settings=imagesEnabled=false")
        options.accept_insecure_certs = True
        options.page_load_strategy = "eager"

        self.driver = webdriver.Remote(
            command_executor="http://127.0.0.1:4444",
            options=options,
        )
        self.driver.set_page_load_timeout(30)
        self.driver.implicitly_wait(10)

    def test_access_esxi(self):
        self.driver.get("https://10.1.100.102/")
        self.assertIn("VMware", self.driver.page_source)

    def tearDown(self):
        driver = getattr(self, "driver", None)
        if driver is not None:
            driver.quit()


if __name__ == "__main__":
    unittest.main()
