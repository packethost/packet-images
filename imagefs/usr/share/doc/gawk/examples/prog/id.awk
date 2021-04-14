# id.awk --- implement id in awk
#
# Requires user and group library functions
#
# Arnold Robbins, arnold@skeeve.com, Public Domain
# May 1993
# Revised February 1996
# Revised May 2014
# Revised September 2014

# output is:
# uid=12(foo) euid=34(bar) gid=3(baz) \
#             egid=5(blat) groups=9(nine),2(two),1(one)

BEGIN {
    uid = PROCINFO["uid"]
    euid = PROCINFO["euid"]
    gid = PROCINFO["gid"]
    egid = PROCINFO["egid"]

    printf("uid=%d", uid)
    pw = getpwuid(uid)
    pr_first_field(pw)

    if (euid != uid) {
        printf(" euid=%d", euid)
        pw = getpwuid(euid)
        pr_first_field(pw)
    }

    printf(" gid=%d", gid)
    pw = getgrgid(gid)
    pr_first_field(pw)

    if (egid != gid) {
        printf(" egid=%d", egid)
        pw = getgrgid(egid)
        pr_first_field(pw)
    }

    for (i = 1; ("group" i) in PROCINFO; i++) {
        if (i == 1)
            printf(" groups=")
        group = PROCINFO["group" i]
        printf("%d", group)
        pw = getgrgid(group)
        pr_first_field(pw)
        if (("group" (i+1)) in PROCINFO)
            printf(",")
    }

    print ""
}

function pr_first_field(str,  a)
{
    if (str != "") {
        split(str, a, ":")
        printf("(%s)", a[1])
    }
}
