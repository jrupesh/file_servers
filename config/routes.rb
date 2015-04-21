# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
resources :file_servers
post '/issues/scan_files', :to => 'issues#scan_files'
patch 'attachments/:object_type/:object_id/scanfiles', :to => 'attachments#scan_files', :as => :object_scan_attachments_files
# resources :issues do
#   member do
#     post 'scan_files'
#   end
# end
