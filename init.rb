require 'ftp_fileserver'

Redmine::Plugin.register :file_servers do
  name 'Project Fileservers plugin'
  author 'Rupesh J'
  description 'This is a plugin for Redmine. Adds a ftp file upload path for each project.'
  version '3.0.2'
  url 'https://github.com/jrupesh/file_servers.git'

  menu :admin_menu, :file_servers, {:controller => 'file_servers', :action => 'index'},
  		 :caption => :label_file_server_plural, :after => :enumerations,
       :html => { :style => 'background-image: url(/plugin_assets/file_servers/images/file_servers.png)' }

	settings  :default => {'organize_uploaded_files' => false, 'organize_uploaded_issue_files' => false, 'selection_on_project_creation' => false},
            :partial => 'settings/file_server_settings'
end
