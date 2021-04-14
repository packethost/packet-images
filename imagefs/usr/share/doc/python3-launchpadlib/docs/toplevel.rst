*********************
Top-level collections
*********************

The launchpad web service's top-level collections provide access to
Launchpad-wide objects like projects and people.

    >>> import httplib2
    >>> httplib2.debuglevel = 1

    >>> from launchpadlib.testing.helpers import salgado_with_full_permissions
    >>> launchpad = salgado_with_full_permissions.login()
    connect: ...
    ...

It's possible to do key-based lookups on the top-level
collections. The bug collection does lookups by bug ID.

    >>> bug = launchpad.bugs[1]
    send: 'GET /.../bugs/1 ...'
    ...

To avoid triggering an HTTP request when simply looking up an object,
you can use a different syntax:

    >>> bug = launchpad.bugs(1)

The HTTP request will happen when you need information that can only
be obtained from the web service.

    >>> print bug.id
    send: 'GET /.../bugs/1 ...'
    ...
    1

Let's look at some more collections. The project collection does
lookups by project name.

    >>> project = launchpad.projects('firefox')
    >>> print project.name
    send: 'GET /.../firefox ...'
    ...
    firefox

The project group collection does lookups by project group name.

    >>> group = launchpad.project_groups('gnome')
    >>> print group.name
    send: 'GET /.../gnome ...'
    ...
    gnome

The distribution collection does lookups by distribution name.

    >>> distribution = launchpad.distributions('ubuntu')
    >>> print distribution.name
    send: 'GET /.../ubuntu ...'
    ...
    ubuntu

The person collection does lookups by a person's Launchpad
name.

    >>> person = launchpad.people('salgado')
    >>> print person.name
    send: 'GET /.../~salgado ...'
    ...
    salgado

    >>> team = launchpad.people('rosetta-admins')
    >>> print team.name
    send: 'GET /1.0/~rosetta-admins ...'
    ...
    rosetta-admins

How does launchpadlib know that 'salgado' is a person and
'rosetta-admins' is a team?

    >>> print person.resource_type_link
    http://.../1.0/#person
    >>> 'default_membership_period' in person.lp_attributes
    False

    >>> print team.resource_type_link
    http://.../1.0/#team
    >>> 'default_membership_period' in team.lp_attributes
    True

The truth is that it doesn't know, not before making that HTTP
request. Until an HTTP request is made, launchpadlib assumes
everything in launchpad.people[] is a team (since a team has strictly
more capabilities than a person).

    >>> person2 = launchpad.people('salgado')
    >>> 'default_membership_period' in person2.lp_attributes
    True

But accessing any attribute of an object--even trying to see what kind
of object 'salgado' is--will trigger the HTTP request that will
determine that 'salgado' is actually a person.

    >>> print person2.resource_type_link
    send: 'GET /.../~salgado ...'
    ...
    http://.../1.0/#person

    >>> 'default_membership_period' in person2.lp_attributes
    False

Accessing an attribute of an object that might be a team will trigger
the HTTP request, and then cause an error if the object turns out not
to be a team.

    >>> person3 = launchpad.people('salgado')
    >>> person3.default_membership_period
    Traceback (most recent call last):
    AttributeError: ...api.launchpad.../~salgado object has no attribute 'default_membership_period'

Cleanup.

    >>> httplib2.debuglevel = None
