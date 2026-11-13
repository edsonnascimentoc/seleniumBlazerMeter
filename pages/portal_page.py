from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


class PortalPage:
    """Interage com o cartao de servico PAE no portal autenticado."""

    PAE_CARD = (By.ID, "card_pae_ambulante")

    def __init__(self, driver, timeout=300):
        self.driver = driver
        self.wait = WebDriverWait(driver, timeout)

    def aguardar_cartao_pae(self):
        return self.wait.until(EC.visibility_of_element_located(self.PAE_CARD))

    def abrir_pae_em_nova_aba(self):
        card = self.aguardar_cartao_pae()
        handles_anteriores = set(self.driver.window_handles)
        destino = card.get_attribute("href")
        if not destino or "d-paeambulante2025.praiagrande.sp.gov.br" not in destino:
            raise AssertionError(f"Destino inesperado no cartao PAE: {destino!r}")

        self.driver.execute_script(
            "arguments[0].scrollIntoView({block:'center', inline:'center'});", card
        )
        self.driver.execute_script("arguments[0].click();", card)

        self.wait.until(
            lambda driver: len(set(driver.window_handles) - handles_anteriores) > 0
            or "/Solicitacao/Local" in driver.current_url
        )
        novas_abas = set(self.driver.window_handles) - handles_anteriores
        if novas_abas:
            self.driver.switch_to.window(novas_abas.pop())
        return destino
