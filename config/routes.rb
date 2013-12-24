# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
resources :file_servers
match '/issues/:id/scan_files', :to => 'issues#scan_files', :via => :post