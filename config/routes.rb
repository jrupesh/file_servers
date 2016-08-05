resources :file_servers
# post '/file_servers/:id/move_local_files', :to => 'file_servers#move_local_files', :as => 'fs_loc_move_files'
# post '/file_servers/cleanup', :to => 'file_servers#cleanup', :as => 'file_server_cleanup'

post '/issues/scan_files', :to => 'issues#scan_files'
patch 'attachments/:object_type/:object_id/scanfiles', :to => 'attachments#scan_files', :as => :object_scan_attachments_files
