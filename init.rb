require 'ftp_fileserver'
require 'file_servers/issue_hook'

Redmine::Plugin.register :file_servers do
  name 'Project Fileservers plugin'
  author 'Rupesh J'
  description 'This is a plugin for Redmine. Adds a ftp file upload path for each project.'
  version '0.0.1'
  #url 'http://example.com/path/to/plugin'
  #author_url 'http://example.com/about'

  menu :admin_menu, :file_servers, {:controller => 'file_servers', :action => 'index'},
  		 :caption => :label_file_server_plural, :after => :enumerations
end
