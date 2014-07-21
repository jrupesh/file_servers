**FTP File Servers**
========

Description:
--------

When a file is uploaded to Redmine it is uploaded in the fileserver.
These files get added eating up the file server space.
The plugin gives the flexibility of associating FTP file servers for each project.

The files attached are uploaded to these ftp servers. The download also happens from these ftp servers.
Thus giving the Redmine users one of the ways to manage their servers effectively.

Installation procedure:
--------

* Follow the default plugin installation procedure of redmine.

* Login as admin, Enable the plugin file server settings.
	![Admin plugin settings](/file_server_admin.jpg "Admin File Server")

* Now add the ftp file servers credentials.
![File Server List](/file_servers_list.jpg "File Servers")
![File Server New](/file_server_new.jpg "New File Server")

* Associate the projects the FTP file server is applicable to.

* Note : Make sure the initial path "/" is not entered in the string.
