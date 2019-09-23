import json
import os
import textwrap
from string import Template

import boto3

BASE_PATH = os.getenv('BASE_PATH') or 'simple'
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
S3_BUCKET = os.getenv('S3_BUCKET')
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


def get_index():
    """ GET /simple/ """
    index = S3.get_object(Bucket=S3_BUCKET, Key='index.html')
    body = index['Body'].read().decode()
    res = proxy_reponse(body)
    return res


def presign(key):
    """ Presign package URLs.

        :param str key: S3 key to presign
    """
    url = S3.generate_presigned_url(
        'get_object',
        ExpiresIn=S3_PRESIGNED_URL_TTL,
        Params={'Bucket': S3_BUCKET, 'Key': key},
        HttpMethod='GET',
    )
    return url


def get_package_index(package):
    """ Handle GET /simple/<pkg>/ requests. """
    # Get keys for given package
    pages = S3_PAGINATOR.paginate(Bucket=S3_BUCKET, Prefix=f'{package}/')
    keys = [key.get('Key') for page in pages for key in page.get('Contents')]

    # Convert keys to presigned URLs
    hrefs = [presign(key) for key in keys]

    # Extract names of packages from keys
    names = [os.path.split(x)[-1] for x in keys]

    # Construct HTML
    anchors = [
        ANCHOR.safe_substitute(href=href, name=name)
        for href, name in zip(hrefs, names)
    ]
    body = INDEX.safe_substitute(
        title=f'Links for {package}',
        anchors=''.join(anchors)
    )

    # Convert to Lambda proxy response
    resp = proxy_reponse(body)

    # Return Lambda prozy response
    return resp


def redirect(path):
    """ Redirect requests. """
    resp = {'statusCode': 301, 'headers': {'Location': path}}
    return resp


def forbidden():
    """ Bad request. """
    resp = {'statusCode': 403}
    return resp


def handler(event, *_):
    """ Handle API Gateway proxy request. """
    print(f'EVENT {json.dumps(event)}')

    # Get HTTP request path
    path = event.get('path').strip('/')

    # Split into path parts
    parts = path.split('/')

    # GET /
    if len(parts) == 1 and path == '':
        res = redirect(BASE_PATH)

    # GET /simple/
    elif len(parts) == 1 and path == BASE_PATH:
        res = get_index()

    # GET /simple/<pkg>/
    elif len(parts) == 2:
        _, package = parts
        res = get_package_index(package)

    # 403 Forbidden
    else:
        res = forbidden()

    # Return proxy response
    print(f'RESPONSE {json.dumps(res)}')
    return res


def reindex(event, *_):
    """ Reindex root. """
    print(f'EVENT {json.dumps(event)}')

    # Get package names from common prefixes
    pages = S3_PAGINATOR.paginate(Bucket=S3_BUCKET, Delimiter='/')
    pkgs = (x.get('Prefix').strip('/')
            for page in pages
            for x in page.get('CommonPrefixes'))

    # Construct HTML
    anchors = (ANCHOR.safe_substitute(href=pkg, name=pkg) for pkg in pkgs)
    body = INDEX.safe_substitute(
        title='Simple index',
        anchors=''.join(anchors)
    )

    # Upload to S3 as index.html
    res = S3.put_object(Bucket=S3_BUCKET, Key='index.html', Body=body.encode())
    return res
