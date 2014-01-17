# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
resources :file_servers
# match '/issues/scan_files', :to => 'issues#scan_files', :via => :post
resources :issues do
  member do
    post 'scan_files'
  end
end
