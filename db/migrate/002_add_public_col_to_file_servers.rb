class AddPublicColToFileServers < ActiveRecord::Migration
  def change
    add_column :file_servers, :is_public, :boolean
  end
end