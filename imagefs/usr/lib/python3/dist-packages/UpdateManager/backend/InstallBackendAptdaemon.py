#!/usr/bin/env python
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
# (c) 2005-2012 Canonical, GPL
# (C) 2008-2009 Sebastian Heinlein <devel@glatzor.de>

from __future__ import print_function

from gi.repository import Gtk

from aptdaemon import client, errors
from defer import inline_callbacks
from aptdaemon.gtk3widgets import (AptCancelButton,
                                   AptConfigFileConflictDialog,
                                   AptDetailsExpander,
                                   AptMediumRequiredDialog,
                                   AptProgressBar)
from aptdaemon.enums import (EXIT_SUCCESS,
                             EXIT_FAILED,
                             STATUS_COMMITTING,
                             STATUS_DOWNLOADING,
                             STATUS_DOWNLOADING_REPO,
                             STATUS_FINISHED,
                             get_error_description_from_enum,
                             get_error_string_from_enum,
                             get_status_string_from_enum)

from UpdateManager.backend import InstallBackend
from UpdateManager.UnitySupport import UnitySupport
from UpdateManager.Dialogs import BuilderDialog

from gettext import gettext as _

import dbus
import os


class UpdateManagerExpander(AptDetailsExpander):
    """An AptDetailsExpander which can be used with multiple terminals.

       The default AptDetailsExpander will shrink/hide when its transaction
       finishes. But here we want to support "chaining" transactions. So we
       override the status-changed handler to only do that when we are
       running the final transaction."""

    def __init__(self, transaction, terminal=True, final=False):
        super().__init__(transaction, terminal)
        self.final = final

    def _on_status_changed(self, trans, status):
        if status in (STATUS_DOWNLOADING, STATUS_DOWNLOADING_REPO):
            self.set_sensitive(True)
            self.download_scrolled.show()
            if self.terminal:
                self.terminal.hide()
        elif status == STATUS_COMMITTING:
            self.download_scrolled.hide()
            if self.terminal:
                self.terminal.show()
                self.set_sensitive(True)
            elif self.final:
                self.set_expanded(False)
                self.set_sensitive(False)
        elif self.final and status == STATUS_FINISHED:
            self.download_scrolled.hide()
            if self.terminal:
                self.terminal.hide()
            self.set_sensitive(False)
            self.set_expanded(False)


class AptStackedProgressBar(Gtk.ProgressBar):
    """ A GtkProgressBar which represents the state of many aptdaemon
    transactions.

    aptdaemon provides AptProgressBar for the state of *one* transaction to
    be represented in a progress bar. This widget creates one of those per
    containing transaction, and scales its progress to the given ratio, so
    one progress bar can show the state of many transactions."""

    def __init__(self, unity):
        self.current_max_progress = 0
        self.progress_bars = []
        self.unity = unity

        super().__init__()

    def add_transaction(self, trans, max_progress):
        assert 0 <= max_progress <= 1

        progress = AptProgressBar(trans)
        self.progress_bars.append(progress)
        progress.min = self.current_max_progress
        self.current_max_progress += max_progress

        if self.current_max_progress > 1:
            self.current_max_progress = 1

        progress.max = self.current_max_progress
        progress.connect("notify::fraction", self._update_progress)
        progress.connect("notify::text", self._update_text)

    def _update_progress(self, inner_progress, data):
        delta = inner_progress.max - inner_progress.min
        position_in_delta = delta * inner_progress.get_fraction()
        new_progress = inner_progress.min + position_in_delta
        self.set_fraction(new_progress)
        self.unity.set_progress(new_progress * 100)

    def _update_text(self, inner_progress, data):
        self.set_text(inner_progress.get_text())


class InstallBackendAptdaemon(InstallBackend, BuilderDialog):
    """Makes use of aptdaemon to refresh the cache and to install updates."""

    def __init__(self, window_main, action):
        InstallBackend.__init__(self, window_main, action)
        ui_path = os.path.join(window_main.datadir,
                               "gtkbuilder/UpdateProgress.ui")
        BuilderDialog.__init__(self, window_main, ui_path,
                               "pane_update_progress")

        self.client = client.AptClient()
        self.unity = UnitySupport()
        self._expanded_size = None
        self.button_cancel = None
        self.trans_failed_msg = None
        self.progressbar = None
        self._active_transaction = None
        self._expander = None

    def close(self):
        if self.button_cancel and self.button_cancel.get_sensitive():
            try:
                self.button_cancel.clicked()
            except Exception:
                # there is not much left to do if the transaction can't be
                # canceled
                pass
            return True
        else:
            return False

    @inline_callbacks
    def update(self):
        """Refresh the package list"""
        try:
            trans = yield self.client.update_cache(defer=True)
            yield self._show_transaction(trans, self.ACTION_UPDATE,
                                         _("Checking for updates…"), False)
        except errors.NotAuthorizedError:
            self._action_done(self.ACTION_UPDATE,
                              authorized=False, success=False,
                              error_string=None, error_desc=None)
        except Exception:
            self._action_done(self.ACTION_UPDATE,
                              authorized=True, success=False,
                              error_string=None, error_desc=None)
            raise

    def _show_transaction_error(self, trans, action):
        error_string = get_error_string_from_enum(trans.error.code)
        error_desc = get_error_description_from_enum(trans.error.code)
        if self.trans_failed_msg:
            trans_failed = True
            error_desc = error_desc + "\n" + self.trans_failed_msg
        else:
            trans_failed = None
        self._action_done(action,
                          authorized=True, success=False,
                          error_string=error_string,
                          error_desc=error_desc,
                          trans_failed=trans_failed)

    def _update_next_package(self, trans, status, action):
        if status == EXIT_FAILED:
            self._show_transaction_error(trans, action)
            return
        self._apt_update_oem()

    @inline_callbacks
    def _apt_update_oem(self):
        assert self._oem_packages_to_update
        elem = self._oem_packages_to_update.pop()
        sources_list_file = f'/etc/apt/sources.list.d/{elem}.list'

        try:
            if os.path.exists(sources_list_file):
                trans = yield self.client.update_cache(
                    sources_list=sources_list_file
                )
                if self._oem_packages_to_update:
                    finished_handler = self._update_next_package
                else:
                    finished_handler = self._on_finished

                yield self._show_transaction(
                    trans,
                    self.ACTION_PRE_INSTALL,
                    _("Installing updates…"), True,
                    on_finished_handler=finished_handler,
                    progress_bar_max=0.1 / self._len_oem_updates
                )
        except errors.NotAuthorizedError:
            self._action_done(self.ACTION_PRE_INSTALL,
                              authorized=False, success=False,
                              error_string=None, error_desc=None)
        except errors.TransactionFailed as e:
            self.trans_failed_msg = str(e)
        except dbus.DBusException as e:
            if e.get_dbus_name() != "org.freedesktop.DBus.Error.NoReply":
                raise
            self._action_done(self.ACTION_PRE_INSTALL,
                              authorized=False, success=False,
                              error_string=None, error_desc=None)
        except Exception:
            self._action_done(self.ACTION_PRE_INSTALL,
                              authorized=True, success=False,
                              error_string=None, error_desc=None)
            raise

    def _update_oem(self, trans, status, action):
        # This is the "finished" handler of installing an oem metapackage
        # What we do now is:
        #  1. update_cache() for the new sources.lists only

        if status == EXIT_FAILED:
            self._show_transaction_error(trans, action)
            return

        (install, _, _, _, _, _) = trans.packages

        self._oem_packages_to_update = set(install)
        self._len_oem_updates = len(install)

        self._apt_update_oem()

    @inline_callbacks
    def commit_oem(self, pkgs_install_oem, pkgs_upgrade_oem):
        self.all_oem_packages = set(pkgs_install_oem) | set(pkgs_upgrade_oem)
        # Nothing to do? Go to the regular updates.
        try:
            if not pkgs_install_oem and not pkgs_upgrade_oem:
                self._action_done(self.ACTION_PRE_INSTALL,
                                  authorized=True, success=True,
                                  error_string=None, error_desc=None,
                                  trans_failed=None)
                return

            if pkgs_install_oem:
                trans = yield self.client.install_packages(pkgs_install_oem,
                                                           defer=True)
                yield self._show_transaction(
                    trans,
                    self.ACTION_PRE_INSTALL,
                    _("Installing updates…"), True,
                    on_finished_handler=self._update_oem,
                    progress_bar_max=0.1
                )
        except errors.NotAuthorizedError:
            self._action_done(self.ACTION_PRE_INSTALL,
                              authorized=False, success=False,
                              error_string=None, error_desc=None)
        except errors.TransactionFailed as e:
            self.trans_failed_msg = str(e)
        except dbus.DBusException as e:
            if e.get_dbus_name() != "org.freedesktop.DBus.Error.NoReply":
                raise
            self._action_done(self.ACTION_PRE_INSTALL,
                              authorized=False, success=False,
                              error_string=None, error_desc=None)
        except Exception:
            self._action_done(self.ACTION_PRE_INSTALL,
                              authorized=True, success=False,
                              error_string=None, error_desc=None)
            raise

    @inline_callbacks
    def commit(self, pkgs_install, pkgs_upgrade, pkgs_remove):
        """Commit a list of package adds and removes"""
        try:
            reinstall = purge = downgrade = []
            trans = yield self.client.commit_packages(
                pkgs_install, reinstall, pkgs_remove, purge, pkgs_upgrade,
                downgrade, defer=True)
            yield self._show_transaction(trans, self.ACTION_INSTALL,
                                         _("Installing updates…"), True)
        except errors.NotAuthorizedError:
            self._action_done(self.ACTION_INSTALL,
                              authorized=False, success=False,
                              error_string=None, error_desc=None)
        except errors.TransactionFailed as e:
            self.trans_failed_msg = str(e)
        except dbus.DBusException as e:
            #print(e, e.get_dbus_name())
            if e.get_dbus_name() != "org.freedesktop.DBus.Error.NoReply":
                raise
            self._action_done(self.ACTION_INSTALL,
                              authorized=False, success=False,
                              error_string=None, error_desc=None)
        except Exception:
            self._action_done(self.ACTION_INSTALL,
                              authorized=True, success=False,
                              error_string=None, error_desc=None)
            raise

    def _on_details_changed(self, trans, details, label_details):
        label_details.set_label(details)

    def _on_status_changed(self, trans, status, label_details):
        label_details.set_label(get_status_string_from_enum(status))
        # Also resize the window if we switch from download details to
        # the terminal window
        if status == STATUS_COMMITTING and self._expander \
           and self._expander.terminal.get_visible():
            self._resize_to_show_details(self._expander)

    @inline_callbacks
    def _show_transaction(self, trans, action, header, show_details,
                          progress_bar_max=1,
                          on_finished_handler=None):

        if on_finished_handler is None:
            on_finished_handler = self._on_finished

        self.label_header.set_label(header)

        if not self.progressbar:
            self.progressbar = AptStackedProgressBar(self.unity)
            self.progressbar.show()
            self.progressbar_slot.add(self.progressbar)

        self.progressbar.add_transaction(trans, progress_bar_max)

        if self.button_cancel:
            self.button_cancel.set_transaction(trans)
        else:
            self.button_cancel = AptCancelButton(trans)
            self.button_cancel.show()
            self.button_cancel_slot.add(self.button_cancel)

        if action == self.ACTION_UPDATE:
            self.button_cancel.set_label(Gtk.STOCK_STOP)

        if show_details:
            if not self._expander:
                self._expander = UpdateManagerExpander(trans)
                self._expander.set_vexpand(True)
                self._expander.set_hexpand(True)
                self._expander.show_all()
                self._expander.connect("notify::expanded",
                                       self._on_expanded)
                self.expander_slot.add(self._expander)
                self.expander_slot.show()
            else:
                self._expander.set_transaction(trans)
            self._expander.final = action != self.ACTION_PRE_INSTALL
        elif self._expander:
            self._expander_slot.hide()

        trans.connect("status-details-changed", self._on_details_changed,
                      self.label_details)
        trans.connect("status-changed", self._on_status_changed,
                      self.label_details)
        trans.connect("finished", on_finished_handler, action)
        trans.connect("medium-required", self._on_medium_required)
        trans.connect("config-file-conflict", self._on_config_file_conflict)

        yield trans.set_debconf_frontend("gnome")
        yield trans.run()

    def _on_expanded(self, expander, param):
        # Make the dialog resizable if the expander is expanded
        # try to restore a previous size
        if not expander.get_expanded():
            self._expanded_size = (expander.terminal.get_visible(),
                                   self.window_main.get_size())
            self.window_main.end_user_resizable()
        elif self._expanded_size:
            term_visible, (stored_width, stored_height) = self._expanded_size
            # Check if the stored size was for the download details or
            # the terminal widget
            if term_visible != expander.terminal.get_visible():
                # The stored size was for the download details, so we need
                # get a new size for the terminal widget
                self._resize_to_show_details(expander)
            else:
                self.window_main.begin_user_resizable(stored_width,
                                                      stored_height)
        else:
            self._resize_to_show_details(expander)

    def _resize_to_show_details(self, expander):
        """Resize the window to show the expanded details.

        Unfortunately the expander only expands to the preferred size of the
        child widget (e.g showing all 80x24 chars of the Vte terminal) if
        the window is rendered the first time and the terminal is also visible.
        If the expander is expanded afterwards the window won't change its
        size anymore. So we have to do this manually. See LP#840942
        """
        if expander.get_expanded():
            win_width, win_height = self.window_main.get_size()
            exp_width = expander.get_allocation().width
            exp_height = expander.get_allocation().height
            if expander.terminal.get_visible():
                terminal_width = expander.terminal.get_char_width() * 80
                terminal_height = expander.terminal.get_char_height() * 24
                new_width = terminal_width - exp_width + win_width
                new_height = terminal_height - exp_height + win_height
            else:
                new_width = win_width + 100
                new_height = win_height + 200
            self.window_main.begin_user_resizable(new_width, new_height)

    def _on_medium_required(self, transaction, medium, drive):
        dialog = AptMediumRequiredDialog(medium, drive, self.window_main)
        res = dialog.run()
        dialog.hide()
        if res == Gtk.ResponseType.OK:
            transaction.provide_medium(medium)
        else:
            transaction.cancel()

    def _on_config_file_conflict(self, transaction, old, new):
        dialog = AptConfigFileConflictDialog(old, new, self.window_main)
        res = dialog.run()
        dialog.hide()
        if res == Gtk.ResponseType.YES:
            transaction.resolve_config_file_conflict(old, "replace")
        else:
            transaction.resolve_config_file_conflict(old, "keep")

    def _on_finished(self, trans, status, action):
        error_string = None
        error_desc = None
        trans_failed = False
        if status == EXIT_FAILED:
            error_string = get_error_string_from_enum(trans.error.code)
            error_desc = get_error_description_from_enum(trans.error.code)
            if self.trans_failed_msg:
                trans_failed = True
                error_desc = error_desc + "\n" + self.trans_failed_msg
        # tell unity to hide the progress again
        self.unity.set_progress(-1)
        is_success = (status == EXIT_SUCCESS)
        try:
            self._action_done(action,
                              authorized=True, success=is_success,
                              error_string=error_string, error_desc=error_desc,
                              trans_failed=trans_failed)
        except TypeError:
            # this module used to be be lazily imported and in older code
            # trans_failed= is not accepted
            # TODO: this workaround can be dropped in Ubuntu 20.10
            self._action_done(action,
                              authorized=True, success=is_success,
                              error_string=error_string, error_desc=error_desc)


if __name__ == "__main__":
    import mock
    options = mock.Mock()
    data_dir = "/usr/share/update-manager"

    from UpdateManager.UpdateManager import UpdateManager
    app = UpdateManager(data_dir, options)

    b = InstallBackendAptdaemon(app, None)
    b.commit(["2vcard"], [], [])
    Gtk.main()
