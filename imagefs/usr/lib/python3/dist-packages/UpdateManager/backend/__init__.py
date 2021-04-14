#!/usr/bin/env python
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-

"""Integration of package managers into UpdateManager"""
# (c) 2005-2009 Canonical, GPL

from __future__ import absolute_import

import gi
gi.require_version('Snapd', '1')
from gi.repository import GLib, Gtk, Snapd

from apt import Cache
import json
import logging
import os
import re
import subprocess
from gettext import gettext as _
from threading import Thread

from UpdateManager.Core.MyCache import MyCache
from UpdateManager.Core.utils import inhibit_sleep, get_dist_version
from UpdateManager.Dialogs import Dialog


class InstallBackend(Dialog):
    ACTION_UPDATE = 0
    ACTION_PRE_INSTALL = 1
    ACTION_INSTALL = 2

    def __init__(self, window_main, action):
        Dialog.__init__(self, window_main)
        self.action = action
        self.sleep_cookie = None

    def start(self):
        os.environ["APT_LISTCHANGES_FRONTEND"] = "none"

        # Do not suspend during the update process
        self.sleep_cookie = inhibit_sleep()

        if self.action == self.ACTION_PRE_INSTALL:
            unfresh_cache = self.window_main.cache
            fresh_cache = Cache(rootdir=self.window_main.cache.rootdir)
            # Install OEM packages, update, then do ACTION_INSTALL
            pkgs_install_oem = []
            pkgs_upgrade_oem = []
            for pkg in self.window_main.oem_metapackages:
                unfresh_pkg = unfresh_cache[pkg]
                fresh_pkg = fresh_cache[pkg]

                if (unfresh_pkg.marked_install
                        and not fresh_pkg.is_installed):
                    pkgs_install_oem.append(pkg)
                elif (unfresh_pkg.marked_upgrade
                      and fresh_pkg.is_upgradable):
                    pkgs_upgrade_oem.append(pkg)
            self.commit_oem(pkgs_install_oem, pkgs_upgrade_oem)
        elif self.action == self.ACTION_INSTALL:
            # Get the packages which should be installed and update
            pkgs_install = []
            pkgs_upgrade = []
            pkgs_remove = []
            # Get a fresh cache in case update-manager's is outdated to
            # skip operations that already took place
            fresh_cache = Cache(rootdir=self.window_main.cache.rootdir)
            for pkg in self.window_main.cache:
                try:
                    if pkg.marked_install \
                       and not fresh_cache[pkg.name].is_installed:
                        pkgname = pkg.name
                        if pkg.is_auto_installed:
                            pkgname += "#auto"
                        pkgs_install.append(pkgname)
                    elif (pkg.marked_upgrade
                          and fresh_cache[pkg.name].is_upgradable):
                        pkgs_upgrade.append(pkg.name)
                    elif (pkg.marked_delete
                          and fresh_cache[pkg.name].is_installed):
                        pkgs_remove.append(pkg.name)
                except KeyError:
                    # pkg missing from fresh_cache can't be modified
                    pass
            self.commit(pkgs_install, pkgs_upgrade, pkgs_remove)
        else:
            self.update()

    def update(self):
        """Run a update to refresh the package list"""
        raise NotImplementedError

    def commit_oem(self, pkgs_install_oem, pkgs_upgrade_oem):
        """ Install these OEM packages """
        self._action_done(self.ACTION_PRE_INSTALL,
                          authorized=True, success=True,
                          error_string=None, error_desc=None,
                          trans_failed=None)

    def commit(self, pkgs_install, pkgs_upgrade, pkgs_remove):
        """Commit the cache changes """
        raise NotImplementedError

    def get_snap_seeds(self):
        seeded_snaps = {}
        unseeded_snaps = {}

        curr_channel = "stable/ubuntu-" + get_dist_version()

        try:
            d2s_file = open(
                '/usr/share/ubuntu-release-upgrader/deb2snap.json', 'r')
            d2s = json.load(d2s_file)
            d2s_file.close()

            for snap in d2s["seeded"]:
                seed = d2s["seeded"][snap]
                deb = seed.get("deb", None)
                to_channel = seed.get("to_channel", curr_channel)
                seeded_snaps[snap] = (deb, to_channel)

            for snap in d2s["unseeded"]:
                unseed = d2s["unseeded"][snap]
                from_channel = unseed.get("from_channel", curr_channel)
                unseeded_snaps[snap] = (from_channel)
        except Exception as e:
            logging.debug("error reading deb2snap.json file (%s)" % e)

        return seeded_snaps, unseeded_snaps

    def get_deb2snap_dups(self):
        # update and grab the latest cache
        try:
            if self.window_main.cache is None:
                self.window_main.cache = MyCache(None)
            else:
                self.window_main.cache.open(None)
                self.window_main.cache._initDepCache()
            cache = self.window_main.cache
        except Exception as e:
            # just return an empty array for now, it's perfectly safe to
            # postpone this duplicates check to a later update.
            logging.debug("error reading cache (%s)" % e)
            return []

        duplicates = []
        seeded_snaps, _ = self.get_snap_seeds()

        for snap, (deb, _) in seeded_snaps.items():
            # if the deb is installed and was not manually installed,
            # replace it
            if (deb in cache and cache[deb].is_installed):
                deb_is_auto = True
                cache[deb].mark_delete()

                for pkg in cache.get_changes():
                    if (pkg.is_installed and pkg.marked_delete
                       and not pkg.is_auto_installed):
                        deb_is_auto = False
                        break

                cache.clear()

                if deb_is_auto:
                    duplicates.append(deb)

        return duplicates

    def get_snap_transitions(self):
        # populate snap_list with deb2snap transitions
        snap_list = {}
        seeded_snaps, unseeded_snaps = self.get_snap_seeds()

        for snap, (deb, to_channel) in seeded_snaps.items():
            snap_object = {}
            # check if the snap is already installed
            snap_info = subprocess.Popen(["snap", "info", snap],
                                         universal_newlines=True,
                                         stdout=subprocess.PIPE).communicate()
            if re.search("^installed: ", snap_info[0], re.MULTILINE):
                logging.debug("Snap %s is installed" % snap)
                continue
            elif (deb in self.window_main.duplicate_packages):
                # install the snap if the deb was just marked delete
                snap_object['command'] = 'install'
                snap_object['channel'] = to_channel
                snap_list[snap] = snap_object

        for snap, (from_channel) in unseeded_snaps.items():
            snap_object = {}
            # check if the snap is already installed
            snap_info = subprocess.Popen(["snap", "info", snap],
                                         universal_newlines=True,
                                         stdout=subprocess.PIPE).communicate()
            if re.search("^installed: ", snap_info[0], re.MULTILINE):
                logging.debug("Snap %s is installed" % snap)
                # its not tracking the release channel so don't remove
                re_channel = "stable/ubuntu-[0-9][0-9].[0-9][0-9]"
                if not re.search(r"^tracking:.*%s" % re_channel,
                                 snap_info[0], re.MULTILINE):
                    logging.debug("Snap %s is not tracking the release channel"
                                  % snap)
                    continue

                snap_object['command'] = 'remove'

                # check if this snap is being used by any other snaps
                conns = subprocess.Popen(["snap", "connections", snap],
                                         universal_newlines=True,
                                         stdout=subprocess.PIPE).communicate()

                for conn in conns[0].split('\n'):
                    conn_cols = conn.split()
                    if len(conn_cols) != 4:
                        continue
                    plug = conn_cols[1]
                    slot = conn_cols[2]

                    if slot.startswith(snap + ':'):
                        plug_snap = plug.split(':')[0]
                        if plug_snap != '-' and \
                           plug_snap not in unseeded_snaps:
                            logging.debug("Snap %s is being used by %s. "
                                          "Switching it to stable track"
                                          % (snap, plug_snap))
                            snap_object['command'] = 'refresh'
                            snap_object['channel'] = 'stable'
                            break

                snap_list[snap] = snap_object

        return snap_list

    def update_snap_cb(self, client, change, _, user_data):
        index, count, progress_bar = user_data
        if not progress_bar:
            return

        # determine how much of this change has been done
        task_total = 0
        task_done = 0
        for task in change.get_tasks():
            task_total += task.get_progress_total()
            task_done += task.get_progress_done()

        task_fraction = task_done / task_total

        # determine how much total progress has been made
        total_fraction = (task_fraction / count) + (index / count)

        # change.get_tasks() can increase between callbacks so we must
        # avoid jumping backward in progress here
        if total_fraction > progress_bar.get_fraction():
            GLib.idle_add(progress_bar.set_fraction, total_fraction)

    def update_snaps(self):
        # update status and progress bar
        def update_status(status):
            GLib.idle_add(self.label_details.set_label, status)

        def update_progress(progress_bar):
            progress_bar.pulse()
            return True

        update_status(_("Updating snaps"))

        progress_bar = None
        progress_timer = None

        progress_bars = self.progressbar_slot.get_children()
        if progress_bars and isinstance(progress_bars[0], Gtk.ProgressBar):
            progress_bar = progress_bars[0]
            progress_timer = GLib.timeout_add(100, update_progress,
                                              progress_bar)

        # populate snap_list with deb2snap transitions
        snap_list = self.get_snap_transitions()

        if progress_timer:
            GLib.source_remove(progress_timer)
            progress_bar.set_fraction(0)

        # (un)install (un)seeded snap(s)
        try:
            client = Snapd.Client()
            client.connect_sync()
            index = 0
            count = len(snap_list)
            for snap, snap_object in snap_list.items():
                command = snap_object['command']
                if command == 'refresh':
                    update_status(_("Refreshing %s snap" % snap))
                    client.refresh_sync(snap, snap_object['channel'],
                                        self.update_snap_cb,
                                        progress_callback_data=(index, count,
                                                                progress_bar))
                elif command == 'remove':
                    update_status(_("Removing %s snap" % snap))
                    client.remove_sync(snap, self.update_snap_cb,
                                       progress_callback_data=(index, count,
                                                               progress_bar))
                else:
                    update_status(_("Installing %s snap" % snap))
                    client.install_sync(snap, snap_object['channel'],
                                        self.update_snap_cb,
                                        progress_callback_data=(index, count,
                                                                progress_bar))
                index += 1
        except GLib.Error as e:
            logging.debug("error updating snaps (%s)" % e)
            GLib.idle_add(self.window_main.start_error, False,
                          _("Upgrade only partially completed."),
                          _("An error occurred while updating snaps. "
                            "Please check your network connection."))
            return

        # continue with the rest of the updates
        GLib.idle_add(self.window_main.start_available)

    def _action_done(self, action, authorized, success, error_string,
                     error_desc, trans_failed=False):

        # If the progress dialog should be closed automatically afterwards
        #settings = Gio.Settings.new("com.ubuntu.update-manager")
        #close_after_install = settings.get_boolean(
        #    "autoclose-install-window")
        # FIXME: confirm with mpt whether this should still be a setting
        #close_after_install = False

        if action == self.ACTION_PRE_INSTALL and success:
            # Now do the regular updates
            self.action = self.ACTION_INSTALL
            self.start()
        elif action == self.ACTION_INSTALL:
            if (success and os.path.exists("/usr/bin/snap")
               and hasattr(self, 'pane_update_progress')):
                Thread(target=self.update_snaps).start()
            elif success:
                self.window_main.start_available()
            elif error_string:
                self.window_main.start_error(trans_failed, error_string,
                                             error_desc)
            else:
                # exit gracefuly, we can't just exit as this will trigger
                # a crash if system.exit() is called in a exception handler
                GLib.timeout_add(1, self.window_main.exit)
        else:
            if error_string:
                self.window_main.start_error(True, error_string, error_desc)
            elif (success and os.path.exists("/usr/bin/snap")
                  and hasattr(self, 'pane_update_progress')):
                self.window_main.duplicate_packages = self.get_deb2snap_dups()
                self.window_main.start_available()
            else:
                is_cancelled_update = not success
                self.window_main.start_available(is_cancelled_update)


# try aptdaemon
if os.path.exists("/usr/sbin/aptd") \
   and "UPDATE_MANAGER_FORCE_BACKEND_SYNAPTIC" not in os.environ:
    # check if the gtkwidgets are installed as well
    try:
        from .InstallBackendAptdaemon import InstallBackendAptdaemon
    except ImportError:
        logging.exception("importing aptdaemon")
# try synaptic
if os.path.exists("/usr/sbin/synaptic") \
   and "UPDATE_MANAGER_FORCE_BACKEND_APTDAEMON" not in os.environ:
    try:
        from .InstallBackendSynaptic import InstallBackendSynaptic
    except ImportError:
        logging.exception("importing synaptic")


def get_backend(*args, **kwargs):
    """Select and return a package manager backend."""
    # try aptdaemon
    if (os.path.exists("/usr/sbin/aptd")
            and "UPDATE_MANAGER_FORCE_BACKEND_SYNAPTIC" not in os.environ):
        # check if the gtkwidgets are installed as well
        try:
            return InstallBackendAptdaemon(*args, **kwargs)
        except NameError:
            logging.exception("using aptdaemon failed")
    # try synaptic
    if (os.path.exists("/usr/sbin/synaptic")
            and "UPDATE_MANAGER_FORCE_BACKEND_APTDAEMON" not in os.environ):
        try:
            return InstallBackendSynaptic(*args, **kwargs)
        except NameError:
            pass
    # nothing found, raise
    raise Exception("No working backend found, please try installing "
                    "aptdaemon or synaptic")
