# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
resources :file_servers
post '/issues/scan_files', :to => 'issues#scan_files'
# resources :issues do
#   member do
#     post 'scan_files'
#   end
# end
