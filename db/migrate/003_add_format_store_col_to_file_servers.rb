class AddFormatStoreColToFileServers < ActiveRecord::Migration
  def change
    add_column :file_servers, :format_store, :text
  end
end