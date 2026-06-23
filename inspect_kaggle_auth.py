import inspect
from kagglesdk.kaggle_http_client import _get_apikey_creds
print(inspect.getsource(_get_apikey_creds))
