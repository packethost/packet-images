require '_h2ph_pre.ph';

no warnings qw(redefine misc);

unless(defined(&_SYS_SOCKET_H)) {
    die("Never include <bits/socket-constants.h> directly; use <sys/socket.h> instead.");
}
eval 'sub SOL_SOCKET () {1;}' unless defined(&SOL_SOCKET);
eval 'sub SO_ACCEPTCONN () {30;}' unless defined(&SO_ACCEPTCONN);
eval 'sub SO_BROADCAST () {6;}' unless defined(&SO_BROADCAST);
eval 'sub SO_DONTROUTE () {5;}' unless defined(&SO_DONTROUTE);
eval 'sub SO_ERROR () {4;}' unless defined(&SO_ERROR);
eval 'sub SO_KEEPALIVE () {9;}' unless defined(&SO_KEEPALIVE);
eval 'sub SO_LINGER () {13;}' unless defined(&SO_LINGER);
eval 'sub SO_OOBINLINE () {10;}' unless defined(&SO_OOBINLINE);
eval 'sub SO_RCVBUF () {8;}' unless defined(&SO_RCVBUF);
eval 'sub SO_RCVLOWAT () {18;}' unless defined(&SO_RCVLOWAT);
eval 'sub SO_RCVTIMEO () {20;}' unless defined(&SO_RCVTIMEO);
eval 'sub SO_REUSEADDR () {2;}' unless defined(&SO_REUSEADDR);
eval 'sub SO_SNDBUF () {7;}' unless defined(&SO_SNDBUF);
eval 'sub SO_SNDLOWAT () {19;}' unless defined(&SO_SNDLOWAT);
eval 'sub SO_SNDTIMEO () {21;}' unless defined(&SO_SNDTIMEO);
eval 'sub SO_TYPE () {3;}' unless defined(&SO_TYPE);
1;
