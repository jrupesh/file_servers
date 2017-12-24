resources :file_servers

# post '/issues/scan_files', :to => 'issues#scan_files'
patch '/:object_type/:object_id/scanfiles', to: 'attachments#scan_files', as: :scan_files

mount DelayedJobWeb => "/delayed_job", anchor: false, via: [:get, :post]
