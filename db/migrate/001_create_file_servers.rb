class CreateFileServers < ActiveRecord::Migration
  def change
  
	  add_column :projects, :file_server_id, :integer
    add_column :attachments, :file_server_id, :integer
	
    create_table :file_servers do |t|
      t.string :name
      t.string :address
      t.integer :port
      t.string :root
      t.integer :protocol
      t.string :login
      t.string :password
      t.boolean :autoscan
    end

  end
end
