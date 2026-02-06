from celery.backends.base import Backend
from celery import Celery
b = Backend(Celery())
exc = {'exc_module':'os',  'exc_type':'system', 'exc_message':'id'}
b.exception_to_python(exc)
