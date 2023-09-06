# Dormantd
### Suspend On Idle network daemon for GNU/Linux
##

Dormantd is a background service for triggering suspend when the computer has very low network trafic. The comnputer is never suspended if some ssh connection is active.

## Installation
* Download dormantd-install.sh intaller file from [here](https://github.com/michaelnpsp/dormantd/releases/) and type in command line:
```
$ sudo bash ./dormantd-install.sh
```
Edit /etc/dormantd.conf file to configure settings and type the command displayed below to reload config:
```
$ sudo systemctl enable --now dormantd
```
