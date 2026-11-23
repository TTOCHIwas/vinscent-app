import base64
import json
import os
import re
import time


def check_x240_config():
    if os.environ.get('DANJJAN_SUPABASE_URL') != 'https://danjjan-api.vinscentlab.com':
        raise ValueError
    token = os.environ.get('DANJJAN_SUPABASE_ANON_KEY', '')
    if not re.fullmatch(r'[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', token):
        raise ValueError
    header, payload, _ = token.split('.')

    def decode(segment):
        return json.loads(base64.urlsafe_b64decode(segment + '=' * (-len(segment) % 4)))

    metadata = decode(header)
    claims = decode(payload)
    expiry = claims.get('exp')
    if (metadata.get('alg') != 'HS256' or claims.get('iss') != 'supabase' or claims.get('role') != 'anon'
            or type(expiry) is not int or expiry <= time.time() + 86400):
        raise ValueError


def main():
    target = os.environ.get('DANJJAN_BACKEND_TARGET')
    if target == 'managed':
        return
    if target != 'x240':
        raise SystemExit('Unexpected release backend target.')
    try:
        check_x240_config()
    except (ValueError, AttributeError):
        raise SystemExit('The X240 release requires the approved HTTPS URL and a valid anon key.') from None


if __name__ == '__main__':
    main()
