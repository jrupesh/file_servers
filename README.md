**FTP File Servers**
========

Description:
--------

When a file is uploaded to Redmine it is uploaded in the fileserver.
These files get added eating up the file server space.
The plugin gives the flexibility of associating FTP file servers for each project.

The files attached are uploaded to these ftp servers. The download also happens from these ftp servers.
Thus giving the Redmine users one of the ways to manage their servers effectively.

All the redmine objects which have file upload feature will be uploaded to the ftp site.

The plugin also provides where in the user can ftp the file from an external client and then attach to the Redmine
objects through a "rescan" functionality available in News, Issues, Wiki, Documents.

Features:
--------

* Overcome the redmine file limit size as the files can be ftp from outside redmine and then added to the Issue with
  a refresh (rescan option) available in the Issue.

* Set public ftps so that the file download is automatic for the user from the Issue page, without being asked for password.

* Browse option in Issue provides a quick access to the ftp directory and the user can navigate through the ftp site.


Installation procedure:
--------

* Follow the default plugin installation procedure of redmine.

* Login as admin, Enable the plugin file server settings.
	![Admin plugin settings](/file_server_admin.jpg "Admin File Server")

* Now add the ftp file servers credentials.
![File Server List](/file_servers_list.jpg "File Servers")
![File Server New](/file_server_new.jpg "New File Server")

* Associate the projects the FTP file server is applicable to.

* Note :
** Make sure the initial path "/" is not entered in the string.
** The preview when issue edit on the ftp site is little slower as the ftp files are fetched from ftp site and rendered.
