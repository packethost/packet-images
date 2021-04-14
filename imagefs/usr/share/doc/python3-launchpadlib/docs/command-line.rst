********************
Command-line scripts
********************

Launchpad includes one command-line script to make Launchpad
integration easier for third-party libraries that aren't written in
Python.

This file tests the workflow underlying the command-line script as
best it can.

RequestTokenApp
===============

This class is called by the command-line script
launchpad-request-token. It creates a request token on a given
Launchpad installation, and returns a JSON description of the request
token and the available access levels.

    >>> try:
    ...     import json
    ... except ImportError:
    ...     import simplejson as json
    >>> from launchpadlib.apps import RequestTokenApp

    >>> web_root = "http://launchpad.test:8085/"
    >>> consumer_name = "consumer"
    >>> token_app = RequestTokenApp(web_root, consumer_name, "context")
    >>> token_json = json.loads(token_app.run())

    >>> for param in sorted(token_json.keys()):
    ...     print(param)
    access_levels
    lp.context
    oauth_token
    oauth_token_consumer
    oauth_token_secret

    >>> print token_json['lp.context']
    context

    >>> print token_json['oauth_token_consumer']
    consumer
