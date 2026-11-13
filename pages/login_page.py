from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait


class LoginPage:
    """Identifica a tela do Login Unico sem ler ou preencher credenciais."""

    CPF = (By.ID, "username")
    PASSWORD = (By.ID, "password")
    SUBMIT = (By.ID, "kcLogin")

    def __init__(self, driver, timeout=300):
        self.driver = driver
        self.wait = WebDriverWait(driver, timeout)

    def aguardar_tela_login(self):
        self.wait.until(EC.visibility_of_element_located(self.CPF))
        self.wait.until(EC.visibility_of_element_located(self.PASSWORD))
        self.wait.until(EC.element_to_be_clickable(self.SUBMIT))
        return True
