import os

import pytest
import requests

PYPI_HOST = os.getenv('PYPI_HOST')
PYPI_USER = os.getenv('PYPI_USER')
PYPI_PASS = os.getenv('PYPI_PASS')
PYPI_AUTH = requests.auth.HTTPBasicAuth(PYPI_USER, PYPI_PASS)


@pytest.mark.parametrize(
    ('url', 'status_code'),
    [
        (f'https://{PYPI_HOST}/simple', 200),
        (f'https://{PYPI_HOST}/simple/dip', 200),
        (f'https://{PYPI_HOST}/simple/boto3', 301),
    ],
)
def test_GET(url, status_code):
    res = requests.get(url, allow_redirects=False, auth=PYPI_AUTH)
    assert res.status_code == status_code
