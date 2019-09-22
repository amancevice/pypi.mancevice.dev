from unittest import mock

import pytest

with mock.patch('boto3.client'):
    import index


def test_proxy_reponse():
    ret = index.proxy_reponse('FIZZ')
    exp = {
        'body': 'FIZZ',
        'headers': {'Content-Type': 'text/html'},
        'statusCode': 200,
    }
    assert ret == exp


def test_get_index():
    index.S3_PAGINATOR.paginate.return_value = iter([
        {
            'CommonPrefixes': [
                {'Prefix': 'simple/fizz/'},
                {'Prefix': 'simple/buzz/'},
            ],
        },
    ])
    ret = index.get_index()
    exp = {
        'body': '''\
<!DOCTYPE html>
<html>
<head>
  <title>Simple Index</title>
</head>
<body>
  <h1>Simple Index</h1>
  <a href="fizz">fizz</a><br>
  <a href="buzz">buzz</a><br>
</body>
</html>
''',
        'headers': {'Content-Type': 'text/html'},
        'statusCode': 200,
    }
    assert ret == exp


def test_get_package_index():
    index.S3.generate_presigned_url.return_value = "<presigned-url>"
    index.S3_PAGINATOR.paginate.return_value = iter([
        {
            'Contents': [
                {'Key': 'simple/fizz/fizz-0.1.2.tar.gz'},
                {'Key': 'simple/fizz/fizz-1.2.3.tar.gz'},
            ],
        },
    ])
    ret = index.get_package_index('fizz')
    exp = {
        'body': '''\
<!DOCTYPE html>
<html>
<head>
  <title>Package Index</title>
</head>
<body>
  <h1>Package Index</h1>
  <a href="<presigned-url>">fizz-0.1.2.tar.gz</a><br>
  <a href="<presigned-url>">fizz-1.2.3.tar.gz</a><br>
</body>
</html>
''',
        'headers': {'Content-Type': 'text/html'},
        'statusCode': 200,
    }
    assert ret == exp


def test_redirect_simple():
    ret = index.redirect_simple()
    exp = {'headers': {'Location': 'simple'}, 'statusCode': 301}
    assert ret == exp


def test_handler():
    event = {'path': '/'}
    ret = index.handler(event)
    exp = {'headers': {'Location': 'simple'}, 'statusCode': 301}
    assert ret == exp
