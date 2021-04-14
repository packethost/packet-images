************
Hosted files
************

The Launchpad web service sets restrictions on what kinds of documents
can be written to a particular file. This test shows what happens when
you try to upload a non-image for a field that expects an image.

    >>> from launchpadlib.testing.helpers import salgado_with_full_permissions
    >>> launchpad = salgado_with_full_permissions.login()
    >>> from launchpadlib.errors import HTTPError

    >>> mugshot = launchpad.me.mugshot
    >>> file_handle = mugshot.open("w", "image/png", "nonimage.txt")
    >>> file_handle.content_type
    'image/png'
    >>> file_handle.filename
    'nonimage.txt'
    >>> file_handle.write("Not an image.")
    >>> try:
    ...     file_handle.close()
    ... except HTTPError, e:
    ...     print e.content
    <BLANKLINE>
    The file uploaded was not recognized as an image; please
    check it and retry.

Of course, uploading an image works fine.

    >>> import os
    >>> def load_image(filename):
    ...     image_file = os.path.join(
    ...         os.path.dirname(__file__), 'files', filename)
    ...     return open(image_file).read()
    >>> image = load_image("mugshot.png")
    >>> len(image)
    2260

    >>> file_handle = mugshot.open("w", "image/png", "a-mugshot.png")
    >>> file_handle.write(image)
    >>> file_handle.close()


== Error handling ==

The server may set restrictions on what kinds of documents can be
written to a particular file.

    >>> file_handle = mugshot.open("w", "image/png", "nonimage.txt")
    >>> file_handle.content_type
    'image/png'
    >>> file_handle.filename
    'nonimage.txt'
    >>> file_handle.write("Not an image.")
    >>> file_handle.close()
    Traceback (most recent call last):
    ...
    BadRequest: HTTP Error 400: Bad Request
    ...

== Caching ==

Hosted file resources implement the normal server-side caching
mechanism.

    >>> file_handle = mugshot.open("w", "image/png", "image.png")
    >>> file_handle.write(image)
    >>> file_handle.close()

    >>> import httplib2
    >>> httplib2.debuglevel = 1
    >>> launchpad = salgado_with_full_permissions.login()
    connect: ...
    >>> mugshot = launchpad.me.mugshot
    send: ...

The first request for a file retrieves the file from the server.

    >>> len(mugshot.open().read())
    send: ...
    reply: 'HTTP/1.1 303 See Other...
    reply: 'HTTP/1.1 200 OK...
    2260

The second request retrieves the file from the cache. After receiving
the 303 request with its Location header, no further HTTP requests are
issued because the Librarian's Cache-Control: headers tell us we
already have a fresh copy.

    >>> len(mugshot.open().read())
    send: ...
    reply: 'HTTP/1.1 303 See Other...
    header: Location: http://.../image.png
    ...
    2260

Finally, some cleanup code that deletes the mugshot.

    >>> mugshot.delete()
    send: 'DELETE...
    reply: 'HTTP/1.1 200...

    >>> httplib2.debuglevel = 0
