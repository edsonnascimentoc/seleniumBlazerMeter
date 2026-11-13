import os

import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

GRID_URL = os.getenv("SELENIUM_GRID_URL", "http://127.0.0.1:4444")
LOGIN_URL = os.getenv(
    "PAE_LOGIN_URL", "https://d-loginunico.praiagrande.sp.gov.br/"
)


@pytest.fixture
def pae_driver():
    options = Options()
    options.page_load_strategy = "none"
    driver = webdriver.Remote(command_executor=GRID_URL, options=options)
    driver.set_window_size(1440, 1000)
    try:
        driver.get(LOGIN_URL)
        yield driver
    finally:
        try:
            driver.quit()
        except Exception:
            # A sessao pode ter expirado ou sido encerrada pelo Grid.
            pass


@pytest.fixture
def timeout_autenticacao():
    return int(os.getenv("PAE_AUTH_TIMEOUT", "300"))
