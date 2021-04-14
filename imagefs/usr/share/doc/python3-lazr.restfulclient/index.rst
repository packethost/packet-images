..
    This file is part of lazr.restfulclient.

    lazr.restfulclient is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, version 3 of the License.

    lazr.restfulclient is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
    License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with lazr.restfulclient.  If not, see <http://www.gnu.org/licenses/>.

LAZR restfulclient
******************

A programmable client library that takes advantage of the commonalities among
lazr.restful web services to provide added functionality on top of wadllib.

Please see https://dev.launchpad.net/LazrStyleGuide and
https://dev.launchpad.net/Hacking for how to develop in this
package.

.. toctree::
   :glob:

   toplevel
   collections
   entries
   operations
   hosted-files
   caching
   authorizer.standalone
   retry.standalone
   NEWS

.. _Sphinx: http://sphinx.pocoo.org/
.. _Table of contents: http://sphinx.pocoo.org/concepts.html#the-toc-tree

Importable
==========

The lazr.restfulclient package is importable, and has a version number.

    >>> import lazr.restfulclient
    >>> print 'VERSION:', lazr.restfulclient.__version__
    VERSION: ...
