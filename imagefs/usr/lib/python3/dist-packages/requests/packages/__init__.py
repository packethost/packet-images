'''
Debian and other distributions "unbundle" requests' vendored dependencies, and
rewrite all imports to use the global versions of ``urllib3`` and ``chardet``.
The problem with this is that not only requests itself imports those
dependencies, but third-party code outside of the distros' control too.

In reaction to these problems, the distro maintainers replaced
``requests.packages`` with a magical "stub module" that imports the correct
modules. The implementations were varying in quality and all had severe
problems. For example, a symlink (or hardlink) that links the correct modules
into place introduces problems regarding object identity, since you now have
two modules in `sys.modules` with the same API, but different identities::

    requests.packages.urllib3 is not urllib3

With version ``2.5.2``, requests started to maintain its own stub, so that
distro-specific breakage would be reduced to a minimum, even though the whole
issue is not requests' fault in the first place. See
https://github.com/kennethreitz/requests/pull/2375 for the corresponding pull
request.
'''

from __future__ import absolute_import
import sys

# On Debian we use the unbundling strategy implemented by pip inside
# pip._vendor.__init__.
def vendored(modulename):
    vendored_name = "{0}.{1}".format(__name__, modulename)

    try:
        __import__(vendored_name, globals(), locals(), level=0)
    except ImportError:
        try:
            __import__(modulename, globals(), locals(), level=0)
        except ImportError:
            # We can just silently allow import failures to pass here. If we
            # got to this point it means that ``import requests.packages.whatever``
            # failed and so did ``import whatever``. Since we're importing this
            # upfront in an attempt to alias imports, not erroring here will
            # just mean we get a regular import error whenever requests
            # *actually* tries to import one of these modules to use it, which
            # actually gives us a better error message than we would have
            # otherwise gotten.
            pass
        else:
            sys.modules[vendored_name] = sys.modules[modulename]
            base, head = vendored_name.rsplit(".", 1)
            setattr(sys.modules[base], head, sys.modules[modulename])

vendored('chardet')
vendored('idna')
vendored('urllib3')
vendored('urllib3._collections')
vendored('urllib3.connection')
vendored('urllib3.connectionpool')
vendored('urllib3.contrib')
vendored('urllib3.contrib.ntlmpool')
vendored('urllib3.contrib.pyopenssl')
vendored('urllib3.exceptions')
vendored('urllib3.fields')
vendored('urllib3.filepost')
vendored('urllib3.packages')
vendored('urllib3.packages.ordered_dict')
vendored('urllib3.packages.six')
vendored('urllib3.packages.ssl_match_hostname')
vendored('urllib3.packages.ssl_match_hostname._implementation')
vendored('urllib3.poolmanager')
vendored('urllib3.request')
vendored('urllib3.response')
vendored('urllib3.util')
vendored('urllib3.util.connection')
vendored('urllib3.util.request')
vendored('urllib3.util.response')
vendored('urllib3.util.retry')
vendored('urllib3.util.ssl_')
vendored('urllib3.util.timeout')
vendored('urllib3.util.url')
