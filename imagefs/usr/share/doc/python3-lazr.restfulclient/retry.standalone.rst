Retry requests on server error
******************************

If lazr.restfulclient talks to a server that sends out a server-side
error with status codes 502 or 503, the client will wait a few seconds
and try the request again. Eventually it will give up and escalate the
error code in the form of an exception.

To test this, let's simulate a lazr.restful server prone to transient
errors using a WSGI application.

    >>> import pkg_resources
    >>> wadl_string = pkg_resources.resource_string(
    ...     'wadllib.tests.data', 'launchpad-wadl.xml')
    >>> representations = { 'application/vnd.sun.wadl+xml' : wadl_string,
    ...                     'application/json' : '{}' }

This application will cause one request to fail for every item in its
BROKEN_RESPONSES list.

    >>> BROKEN_RESPONSES = []
    >>> def broken_application(environ, start_response):
    ...     if len(BROKEN_RESPONSES) > 0:
    ...         start_response(str(BROKEN_RESPONSES.pop()),
    ...                        [('Content-type', 'text/plain')])
    ...         return ["Sorry, I'm still broken."]
    ...     else:
    ...         media_type = environ['HTTP_ACCEPT']
    ...         content = representations[media_type]
    ...         start_response(
    ...             '200', [('Content-type', media_type)])
    ...         return [content]

    >>> def make_broken_application():
    ...     return broken_application

    >>> import wsgi_intercept
    >>> wsgi_intercept.add_wsgi_intercept(
    ...     'api.launchpad.dev', 80, make_broken_application)
    >>> BROKEN_RESPONSES = []

    >>> from wsgi_intercept.httplib2_intercept import install
    >>> install()

Here's a fake implementation of time.sleep() so that this test doesn't
take a really long time to run, and so we can visualize sleep() being
called as lazr.restfulclient retries over and over again.

    >>> def fake_sleep(time):
    ...     print "sleep(%s) called" % time
    >>> import lazr.restfulclient._browser
    >>> old_sleep = lazr.restfulclient._browser.sleep
    >>> lazr.restfulclient._browser.sleep = fake_sleep

As it starts out, the application isn't broken at all.

    >>> from lazr.restfulclient.resource import ServiceRoot
    >>> client = ServiceRoot(None, "http://api.launchpad.dev/")

Let's queue up one broken response. The client will sleep once and
try again.

    >>> BROKEN_RESPONSES = [502]
    >>> client = ServiceRoot(None, "http://api.launchpad.dev/")
    sleep(0) called

Now the application will fail six times and then start working.

    >>> BROKEN_RESPONSES = [502, 503, 502, 503, 502, 503]
    >>> client = ServiceRoot(None, "http://api.launchpad.dev/")
    sleep(0) called
    sleep(1) called
    sleep(2) called
    sleep(4) called
    sleep(8) called
    sleep(16) called

Now the application will fail seven times and then start working. But
the client will give up before then--it will only retry the request
six times.

    >>> BROKEN_RESPONSES = [502, 503, 502, 503, 502, 503, 502]
    >>> client = ServiceRoot(None, "http://api.launchpad.dev/")
    Traceback (most recent call last):
    ...
    ServerError: HTTP Error 502:
    ...

By increasing the 'max_retries' constructor argument, we can make the
application try more than six times, and eventually succeed.

    >>> BROKEN_RESPONSES = [502, 503, 502, 503, 502, 503, 502]
    >>> client = ServiceRoot(None, "http://api.launchpad.dev/",
    ...                      max_retries=10)
    sleep(0) called
    sleep(1) called
    sleep(2) called
    sleep(4) called
    sleep(8) called
    sleep(16) called
    sleep(32) called

Now the application will fail once and then give a 400 error. The
client will not retry in hopes that the 400 error will go away--400 is
a client error.

    >>> BROKEN_RESPONSES = [502, 400]
    >>> client = ServiceRoot(None, "http://api.launchpad.dev/")
    Traceback (most recent call last):
    ...
    BadRequest: HTTP Error 400:
    ...

Teardown.

    >>> _ = wsgi_intercept.remove_wsgi_intercept("api.launchpad.dev", 80)
    >>> lazr.restfulclient._browser.sleep = old_sleep
