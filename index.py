import json
import os
import re
import textwrap
from string import Template

import boto3

ANCHOR = Template('\n  <a href="$href">$name</a><br>')
INDEX = Template(textwrap.dedent('''\
    <!DOCTYPE html>
    <html>
    <head>
      <title>$title</title>
    </head>
    <body>
      <h1>$title</h1>$anchors
    </body>
    </html>
'''))
S3 = boto3.client('s3')
S3_BUCKET = os.getenv('S3_BUCKET') or 'pypi.mancevice.dev'
S3_PAGINATOR = S3.get_paginator('list_objects')
S3_PRESIGNED_URL_TTL = int(os.getenv('S3_PRESIGNED_URL_TTL') or 900)


def proxy_reponse(body):
    """ Convert HTML to API Gateway response.

        :param str body: HTML body
        :return dict: API Gateway Lambda proxy response
    """
    # Wrap HTML in proxy response object
    resp = {
        'body': body,
        'headers': {'Content-Type': 'text/html'},
        'statusCode': 200,
    }
    return resp


def get_index(*_):
    """ Handle GET /simple/ requests. """
    # Get package names from common prefixes
    pages = S3_PAGINATOR.paginate(
        Bucket=S3_BUCKET,
        Delimiter='/',
        Prefix='simple/',
    )
    prefixes = (
        x.get('Prefix').strip('/').split('/')
        for page in pages
        for x in page.get('CommonPrefixes')
    )
    _, pkgs = zip(*prefixes)

    # Construct HTML
    anchors = (ANCHOR.safe_substitute(href=pkg, name=pkg) for pkg in pkgs)
    body = INDEX.safe_substitute(
        title='Simple Index',
        anchors=''.join(anchors),
    )

    # Convert to Lambda proxy response
    resp = proxy_reponse(body)

    # Return Lambda prozy response
    return resp


def get_package_index(path):
    """ Handle GET /simple/<pkg>/ requests. """
    # Get keys for given package
    pages = S3_PAGINATOR.paginate(Bucket=S3_BUCKET, Prefix=path.lstrip('/'))
    keys = [key.get('Key') for page in pages for key in page.get('Contents')]

    # Convert keys to presigned URLs
    hrefs = [
        S3.generate_presigned_url(
            'get_object',
            ExpiresIn=S3_PRESIGNED_URL_TTL,
            Params={'Bucket': S3_BUCKET, 'Key': key},
            HttpMethod='GET',
        )
        for key in keys
    ]

    # Extract names of packages from keys
    names = [os.path.split(x)[-1] for x in keys]

    # Construct HTML
    anchors = [
        ANCHOR.safe_substitute(href=href, name=name)
        for href, name in zip(hrefs, names)
    ]
    body = INDEX.safe_substitute(
        title='Package Index',
        anchors=''.join(anchors),
    )

    # Convert to Lambda proxy response
    resp = proxy_reponse(body)

    # Return Lambda prozy response
    return resp


def redirect_simple(*_):
    """ Handle GET / requests. """
    # Redirect / to /simple/
    resp = {'statusCode': 301, 'headers': {'Location': 'simple'}}
    return resp


def handler(event, context=None):
    """ Handle API Gateway proxy request. """
    print(f'EVENT {json.dumps(event)}')

    # Get HTTP request path
    path = event.get('path')

    # Get first route that matches path
    func = next(
        func for ptn, func in ROUTER.items()
        if re.match(ptn, path, re.IGNORECASE)
    )

    # Get proxy response
    resp = func(path)
    print(f'RESPONSE {json.dumps(resp)}')

    # Return proxy response
    return resp


# PyPI router
ROUTER = {
    r'^/$': redirect_simple,
    r'^/simple/?$': get_index,
    r'^/simple/([^/]+)/?$': get_package_index,
}
