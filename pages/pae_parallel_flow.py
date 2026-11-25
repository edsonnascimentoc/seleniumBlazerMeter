from pages.login_page import LoginPage
from pages.portal_page import PortalPage
from pages.pae_page import PAEPage


def validar_fluxo_pae(driver, timeout_autenticacao):
    """
    Valida uma sessão autenticada manualmente até a página inicial do PAE.

    Não lê nem preenche credenciais e não envia solicitações ou cadastros.
    """
    login = LoginPage(driver, timeout=timeout_autenticacao)
    portal = PortalPage(driver, timeout=timeout_autenticacao)
    pae = PAEPage(driver, timeout=90)

    login.aguardar_tela_login()
    portal.aguardar_cartao_pae()
    portal.abrir_pae_em_nova_aba()

    url_final = pae.aguardar_pagina_local()
    assert "/Solicitacao/Local" in url_final
    assert "d-paeambulante2025.praiagrande.sp.gov.br" in url_final
    return url_final
