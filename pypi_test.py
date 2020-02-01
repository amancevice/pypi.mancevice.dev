import os

import requests

PYPI_HOST = os.getenv('PYPI_HOST')
PYPI_USER = os.getenv('PYPI_USER')
PYPI_PASS = os.getenv('PYPI_PASS')
PYPI_AUTH = requests.auth.HTTPBasicAuth(PYPI_USER, PYPI_PASS)


def test_get_simple():
    res = requests.get(f'https://{PYPI_HOST}/simple', auth=PYPI_AUTH)
    assert res.status_code == 200


def test_get_simple_pip():
    res = requests.get(f'https://{PYPI_HOST}/simple/dip', auth=PYPI_AUTH)
    assert res.status_code == 200
