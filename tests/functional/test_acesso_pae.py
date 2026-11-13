import pytest

from pages.login_page import LoginPage
from pages.portal_page import PortalPage
from pages.pae_page import PAEPage


@pytest.mark.pae_manual_auth
def test_login_unico_ate_pagina_local_pae(pae_driver, timeout_autenticacao):
    """
    O operador autentica manualmente no noVNC.
    O teste nao le CPF/senha, nao submete formularios de cadastro e nao
    executa solicitacoes de vaga.
    """
    login = LoginPage(pae_driver, timeout=timeout_autenticacao)
    portal = PortalPage(pae_driver, timeout=timeout_autenticacao)
    pae = PAEPage(pae_driver, timeout=90)

    login.aguardar_tela_login()

    # A autenticacao e manual: aguarda o cartao de servico aparecer no portal.
    portal.aguardar_cartao_pae()
    portal.abrir_pae_em_nova_aba()

    url_final = pae.aguardar_pagina_local()
    assert "/Solicitacao/Local" in url_final
    assert "d-paeambulante2025.praiagrande.sp.gov.br" in url_final
