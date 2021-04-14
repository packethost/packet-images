#!/usr/bin/python3


# nice apt-get -s -o Debug::NoLocking=true upgrade | grep ^Inst

import apt
import apt_pkg
import os
import sys
from optparse import OptionParser
import gettext
import subprocess

SYNAPTIC_PINFILE = "/var/lib/synaptic/preferences"
DISTRO = subprocess.check_output(
    ["lsb_release", "-c", "-s"],
    universal_newlines=True).strip()

ESM_ORIGINS = ("UbuntuESM", "UbuntuESMApps")


def _(msg):
    return gettext.dgettext("update-notifier", msg)


def _handleException(type, value, tb):
    sys.stderr.write("E: " + _("Unknown Error: '%s' (%s)") % (type, value))
    sys.exit(-1)


def clean(cache, depcache):
    " unmark (clean) all changes from the given depcache "
    # mvo: looping is too inefficient with the new auto-mark code
    # for pkg in cache.Packages:
    #     depcache.MarkKeep(pkg)
    depcache.init()


def saveDistUpgrade(cache, depcache):
    """ this function mimics a upgrade but will never remove anything """
    depcache.upgrade(True)
    if depcache.del_count > 0:
        clean(cache, depcache)
    depcache.upgrade()


def isSecurityUpgrade(ver):
    " check if the given version is a security update (or masks one) "
    security_pockets = [("Ubuntu", "%s-security" % DISTRO),
                        ("UbuntuESM", "%s-infra-security" % DISTRO),
                        ("UbuntuESMApps", "%s-apps-security" % DISTRO),
                        ("gNewSense", "%s-security" % DISTRO),
                        ("Debian", "%s-updates" % DISTRO)]
    for (file, index) in ver.file_list:
        for origin, archive in security_pockets:
            if (file.archive == archive and file.origin == origin):
                return True
    return False


def isESMUpgrade(ver):
    " check if the given version is a security update (or masks one) "
    for (file, index) in ver.file_list:
        if file.origin in ESM_ORIGINS and file.archive.startswith(DISTRO):
            return True
    return False


def write_package_names(outstream, cache, depcache):
    " write out package names that change to outstream "
    pkgs = [pkg for pkg in cache.packages if depcache.marked_install(pkg)
            or depcache.marked_upgrade(pkg)]
    outstream.write("\n".join([p.name for p in pkgs]))


def write_human_readable_summary(outstream, upgrades, security_updates,
                                 esm_updates, have_esm, disabled_esm_updates):
    " write out human summary summary to outstream "
    if have_esm is not None:
        if have_esm:
            outstream.write(gettext.dgettext("update-notifier",
                                             "UA Infra: Extended "
                                             "Security Maintenance (ESM) is "
                                             "enabled."))
        else:
            outstream.write(gettext.dgettext("update-notifier",
                                             "UA Infra: Extended "
                                             "Security Maintenance (ESM) is "
                                             "not enabled."))
        outstream.write("\n\n")

    outstream.write(gettext.dngettext("update-notifier",
                                      "%i update can be installed "
                                      "immediately.",
                                      "%i updates can be installed "
                                      "immediately.",
                                      upgrades) % upgrades)
    outstream.write("\n")
    if esm_updates > 0:
        outstream.write(gettext.dngettext("update-notifier",
                                          "%i of these updates is fixed "
                                          "through UA Infra: ESM.",
                                          "%i of these updates are "
                                          "fixed through UA "
                                          "Infra: ESM.",
                                          esm_updates) %
                        esm_updates)
        outstream.write("\n")
    outstream.write(gettext.dngettext("update-notifier",
                                      "%i of these updates is a "
                                      "security update.",
                                      "%i of these updates are "
                                      "security updates.",
                                      security_updates) %
                    security_updates)
    if upgrades > 0 or security_updates > 0 or esm_updates > 0:
        outstream.write("\n")
        outstream.write(gettext.dgettext("update-notifier",
                                         "To see these additional updates "
                                         "run: apt list --upgradable"))
    if have_esm is not None and not have_esm:
        outstream.write("\n")
        if disabled_esm_updates > 0:
            outstream.write("\n")
            outstream.write(gettext.dngettext("update-notifier",
                                              "Enable UA Infra: ESM "
                                              "to receive %i additional "
                                              "security update.",
                                              "Enable UA Infra: ESM "
                                              "to receive %i additional "
                                              "security updates.",
                                              disabled_esm_updates) %
                            disabled_esm_updates)
        else:
            outstream.write("\n")
            outstream.write(gettext.dgettext("update-notifier",
                                             "Enable UA Infra: ESM to "
                                             "receive additional future "
                                             "security updates."))
        outstream.write("\n")
        outstream.write(gettext.dgettext("update-notifier",
                                         "See https://ubuntu.com/security/esm "
                                         "or run: sudo ua status"))
    outstream.write("\n")


def has_disabled_esm_security_update(depcache, pkg):
    " check if we have a disabled ESM security update "
    inst_ver = pkg.current_ver
    if not inst_ver:
        return False

    for ver in pkg.version_list:
        if ver == inst_ver:
            break

        for (file, index) in ver.file_list:
            if (file.origin in ESM_ORIGINS and file.archive.startswith(DISTRO)
                    and depcache.policy.get_priority(file) == -32768):
                return True
    return False


def init():
    " init the system, be nice "
    # FIXME: do a ionice here too?
    os.nice(19)
    apt_pkg.init()


def run(options=None):

    # we are run in "are security updates installed automatically?"
    # question mode
    if options.security_updates_unattended:
        res = apt_pkg.config.find_i("APT::Periodic::Unattended-Upgrade", 0)
        # print(res)
        sys.exit(res)

    # get caches
    try:
        cache = apt_pkg.Cache(apt.progress.base.OpProgress())
    except SystemError as e:
        sys.stderr.write("E: " + _("Error: Opening the cache (%s)") % e)
        sys.exit(-1)
    depcache = apt_pkg.DepCache(cache)

    # read the synaptic pins too
    if os.path.exists(SYNAPTIC_PINFILE):
        depcache.read_pinfile(SYNAPTIC_PINFILE)
        depcache.init()

    if depcache.broken_count > 0:
        sys.stderr.write("E: " + _("Error: BrokenCount > 0"))
        sys.exit(-1)

    # do the upgrade (not dist-upgrade!)
    try:
        saveDistUpgrade(cache, depcache)
    except SystemError as e:
        sys.stderr.write("E: " + _("Error: Marking the upgrade (%s)") % e)
        sys.exit(-1)

    # Check if we have ESM enabled or disabled; and if it exists in the
    # first place.
    have_esm = None        # None == does not exist
    for file in cache.file_list:
        if file.origin in ESM_ORIGINS and file.archive.startswith(DISTRO):
            # In case of multiple ESM repos, one enabled is sufficient.
            if depcache.policy.get_priority(file) == -32768:
                # We found a disabled ESM repository, but we'll only count
                # ESM as disabled here if we have not found any other ESM
                # repo, so one ESM repo being enabled means ESM is enabled.
                if have_esm is None:
                    have_esm = False
            else:
                have_esm = True
                break

    # analyze the ugprade
    upgrades = 0
    security_updates = 0
    esm_updates = 0
    disabled_esm_updates = 0

    # we need another cache that has more pkg details
    with apt.Cache() as aptcache:
        for pkg in cache.packages:
            if has_disabled_esm_security_update(depcache, pkg):
                disabled_esm_updates += 1

            # skip packages that are not marked upgraded/installed
            if not (depcache.marked_install(pkg)
                    or depcache.marked_upgrade(pkg)):
                continue
            # check if this is really a upgrade or a false positive
            # (workaround for ubuntu #7907)
            inst_ver = pkg.current_ver
            cand_ver = depcache.get_candidate_ver(pkg)
            if cand_ver == inst_ver:
                continue
            # check for security upgrades
            if isSecurityUpgrade(cand_ver):
                if isESMUpgrade(cand_ver):
                    esm_updates += 1
                upgrades += 1
                security_updates += 1
                continue

            # check to see if the update is a phased one
            try:
                from UpdateManager.Core.UpdateList import UpdateList
                ul = UpdateList(None)
                ignored = ul._is_ignored_phased_update(
                    aptcache[pkg.get_fullname()])
                if ignored:
                    depcache.mark_keep(pkg)
                    continue
            except ImportError:
                pass

            upgrades = upgrades + 1

            # now check for security updates that are masked by a
            # candidate version from another repo (-proposed or -updates)
            for ver in pkg.version_list:
                if (inst_ver
                        and apt_pkg.version_compare(ver.ver_str,
                                                    inst_ver.ver_str) <= 0):
                    continue
                if isESMUpgrade(ver):
                    esm_updates += 1
                if isSecurityUpgrade(ver):
                    security_updates += 1
                    break

    # print the number of upgrades
    if options and options.show_package_names:
        write_package_names(sys.stderr, cache, depcache)
    elif options and options.readable_output:
        write_human_readable_summary(sys.stdout, upgrades, security_updates,
                                     esm_updates, have_esm,
                                     disabled_esm_updates)
    else:
        # print the number of regular upgrades and the number of
        # security upgrades
        sys.stderr.write("%s;%s" % (upgrades, security_updates))

    # return the number of upgrades (if its used as a module)
    return(upgrades, security_updates)


if __name__ == "__main__":
    # setup a exception handler to make sure that uncaught stuff goes
    # to the notifier
    sys.excepthook = _handleException

    # gettext
    APP = "update-notifier"
    DIR = "/usr/share/locale"
    gettext.bindtextdomain(APP, DIR)
    gettext.textdomain(APP)

    # check arguments
    parser = OptionParser()
    parser.add_option("-p",
                      "--package-names",
                      action="store_true",
                      dest="show_package_names",
                      help=_("Show the packages that are "
                             "going to be installed/upgraded"))
    parser.add_option("",
                      "--human-readable",
                      action="store_true",
                      dest="readable_output",
                      help=_("Show human readable output on stdout"))
    parser.add_option("",
                      "--security-updates-unattended",
                      action="store_true",
                      help=_("Return the time in days when security updates "
                             "are installed unattended (0 means disabled)"))
    (options, args) = parser.parse_args()

    # run it
    init()
    run(options)
