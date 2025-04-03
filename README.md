# jenkins-n-keytar

Jenkins build agent with the ability to install the npm keytar package for credential management.

**NOTE:** This image must have the capability `IPC_LOCK` or run as privilaged to properly operate. This can be done on the run command by adding `--cap-add ipc_lock` or `--privileged` respectively. Not specifying this capability will result in the following messages when trying to start the gnome keyring daemon: 

```
gnome-keyring-daemon: Operation not permitted
```

## Usage

In general, nothing special will need to be done when connecting to the machine with the jenkins username and password.

If you have troubles accessing the keyring in the container you will most likely be seeing this error message: 

```
** Message: Remote error from secret service: org.freedesktop.DBus.Error.UnknownMethod: No such interface 'org.freedesktop.Secret.Collection' on object at path /org/freedesktop/secrets/collection/login
```

To correct this, issue the following console command before you attempt to access the keyring:

```
echo 'jenkins' | gnome-keyring-daemon -r -d --unlock
```