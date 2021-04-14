****************
Named operations
****************

launchpadlib can transparently determine the size of the list even
when the size is not directly provided, but is only available through
a link.

    >>> from launchpadlib.testing.helpers import salgado_with_full_permissions
    >>> launchpad = salgado_with_full_permissions.login(version="devel")

    >>> results = launchpad.people.find(text='s')
    >>> 'total_size' in results._wadl_resource.representation.keys()
    False
    >>> 'total_size_link' in results._wadl_resource.representation.keys()
    True
    >>> len(results) > 1
    True

Of course, launchpadlib can also determine the size when the size _is_
directly provided.

    >>> results = launchpad.people.find(text='salgado')
    >>> 'total_size' in results._wadl_resource.representation.keys()
    True
    >>> len(results) == 1
    True
