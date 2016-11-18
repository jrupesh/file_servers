resources :file_servers

post '/issues/scan_files', :to => 'issues#scan_files'
patch 'attachments/:object_type/:object_id/scanfiles', :to => 'attachments#scan_files', :as => :object_scan_attachments_files
