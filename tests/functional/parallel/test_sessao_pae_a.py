import pytest

from pages.pae_parallel_flow import validar_fluxo_pae


@pytest.mark.pae_manual_auth
@pytest.mark.pae_parallel_auth
def test_sessao_pae_a(pae_driver, timeout_autenticacao):
    """Primeira sessão independente; autenticação realizada pelo operador."""
    validar_fluxo_pae(pae_driver, timeout_autenticacao)
