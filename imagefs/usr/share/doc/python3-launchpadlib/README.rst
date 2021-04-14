Script Launchpad through its web services interfaces.  Officially supported.

..
    Copyright (C) 2008-2009 Canonical Ltd.

    This file is part of launchpadlib.

    launchpadlib is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, version 3 of the License.

    launchpadlib is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
    License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with launchpadlib.  If not, see <http://www.gnu.org/licenses/>.


Overview
========

launchpadlib is a standalone Python library for scripting Launchpad through
its web services interface.  It is the officially supported bindings to the
Launchpad web service, but there may be third party bindings that provide
scriptability for other languages.

Launchpad (http://launchpad.net) is a a free software hosting and development
website, making it easy to collaborate across multiple projects. For
information on Launchpad itself, see

    https://help.launchpad.net

More information on the Launchpad web service, such as user guides and
reference documentation, are available at

    https://help.launchpad.net/API

Client documentation for launchpadlib is available at

    https://help.launchpad.net/API/launchpadlib

Please submit bug reports to

    https://bugs.launchpad.net/launchpadlib


Credential storage
==================

After authorizing an application to access Launchpad on a user's behalf,
launchpadlib will attempt to store those credentials in the most
system-appropriate way.  That is, on Gnome it will store them in the Gnome
keyring, on KDE it will store them in the KDE wallet and if neither of those
is available it will store them on disk.
