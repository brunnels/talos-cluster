import glob, json, re, os
DEFAULT_BINARY_PATHS = {'pg': sorted([''] + glob.glob('/usr/pgsql-*/bin')).pop()}
with open('/etc/pgadmin/conf.d/~postgres-operator/pgadmin-oidc-settings.json') as _f:
    _conf, _data = re.compile(r'[A-Z_0-9]+'), json.load(_f)
    if type(_data) is dict:
        globals().update({k: v for k, v in _data.items() if _conf.fullmatch(k)})
with open('/etc/pgadmin/conf.d/~postgres-operator/pgadmin-settings.json') as _f:
    _conf, _data = re.compile(r'[A-Z_0-9]+'), json.load(_f)
    if type(_data) is dict:
        globals().update({k: v for k, v in _data.items() if _conf.fullmatch(k)})
if os.path.isfile('/etc/pgadmin/conf.d/~postgres-operator/ldap-bind-password'):
    with open('/etc/pgadmin/conf.d/~postgres-operator/ldap-bind-password') as _f:
        LDAP_BIND_PASSWORD = _f.read()
if os.path.isfile('/etc/pgadmin/conf.d/~postgres-operator/config-database-uri'):
    with open('/etc/pgadmin/conf.d/~postgres-operator/config-database-uri') as _f:
        CONFIG_DATABASE_URI = _f.read()
