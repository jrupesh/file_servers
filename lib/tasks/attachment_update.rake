namespace :fileserver do

  desc  <<-END_DESC
Checks attachments on FTP File server, And updates the path if not available.
Example:
  rake fileserver:check_attachment RAILS_ENV="production"
END_DESC
  task :check_attachment => :environment do

  end

  desc 'Move attachments from APP Server to the FTP File server.'
  task :move_attachments => :environment do

  end

  desc  <<-END_DESC
Update attachments from APP Server to the FTP File server.
Example:
  rake fileserver:update_attachment source=attachmentname target=project RAILS_ENV="production"
END_DESC
  task :update_attachment => :environment do
    source_name = ENV['source'] || nil
    abort "Source attachment File name not specified." if source_name.nil?

    target_project_identifier = ENV['target'] || nil
    abort("target project identifier not specified") if target_project_identifier.nil?

    project = Project.find_by_identifier(target_project_identifier)
    fail("target project does not exist") if project.nil?

    attachment = Attachment.find_by_filename(source_name)
    attachment = Attachment.find_by_disk_filename(source_name) if attachment.nil?

    abort("Attachment not found") if attachment.nil?

    attachment.file_server_id = project.file_server_id
    attachment.save
  end
end