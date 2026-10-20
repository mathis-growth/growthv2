import hmac, hashlib, base64, json, sys
S = b"auditoria-growths-segredo-local-com-32-chars-ou-mais"
b = lambda x: base64.urlsafe_b64encode(json.dumps(x, separators=(',', ':')).encode()).rstrip(b'=')
def token(sub='00000000-0000-0000-0000-00000000a0a0', role='authenticated', email='auditoria@escolaaurora.com.br'):
    h = b({'alg': 'HS256', 'typ': 'JWT'}); p = b({'sub': sub, 'role': role, 'email': email, 'aud': 'authenticated', 'exp': 4102444800})
    s = base64.urlsafe_b64encode(hmac.new(S, h + b'.' + p, hashlib.sha256).digest()).rstrip(b'=')
    return (h + b'.' + p + b'.' + s).decode()
ANON = None
if __name__ == '__main__': print(token(*sys.argv[1:]))
