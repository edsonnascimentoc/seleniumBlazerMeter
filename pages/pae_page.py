
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


class PAEPage:
    """Validacoes da pagina inicial de selecao de local do PAE."""

    TITULO = (
        By.XPATH,
        "//h3[normalize-space()='Informações']"
    )

    def __init__(self, driver, timeout=90):
        self.driver = driver
        self.wait = WebDriverWait(driver, timeout)

    def aguardar_pagina_local(self):
        self.wait.until(
            EC.url_contains("/Solicitacao/Local")
        )

        self.wait.until(
            EC.visibility_of_element_located(self.TITULO)
        )

        titulo = self.driver.title

        if "PAE" not in titulo:
            raise AssertionError(
                f"Titulo inesperado na pagina PAE: {titulo!r}"
            )

        return self.driver.current_url
