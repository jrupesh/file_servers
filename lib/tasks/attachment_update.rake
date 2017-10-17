namespace :fileserver do

  desc  <<-END_DESC
Checks attachments on Redmine Storage, If the attachment is on FTP File server moves it to a temporary directory specified.
Which can be deleted later on, after verification.
Example:
  rake fileserver:attachment_cleanup temp=/tmp/REDMINE action=dryrun|delete RAILS_ENV="production"
END_DESC
  task :attachment_cleanup => :environment do
    target = ENV['temp']
    abort("Target folder not specified.") if target.nil?

    action = ENV['action']
    abort("Action not specified.") if action.nil?

    # Get list of file names from the redmine storage.
    search_path = Attachment.storage_path || './files'
    files = Dir["#{search_path}/**/*"]

    disk_filenames = []
    disk_filenames_path = {}
    files.each do |f_path|
      next if File.directory?(f_path)
      f_name = File.basename("#{f_path}")
      disk_filenames << f_name
      disk_filenames_path[f_name] = f_path
    end

    db_count   = 0
    nofile_count = 0
    move_count = 0
    remove_count = 0
    Attachment.where("file_server_id is not NULL and disk_filename in (?)", disk_filenames ).all.find_in_batches( batch_size: 1000, start: 0 ) do |batch|
      batch.each do |file|
        db_count += 1

        redmine_src = disk_filenames_path[file.disk_filename]

        unless File.exists?(redmine_src)
          nofile_count += 1
          next
        end

        path =  File.join( target, redmine_src.gsub(search_path, "") )

        if action == "dryrun"
          begin
            unless file.ftpfileexists?
              move_count += 1
            end
            remove_count += 1
          rescue Exception => e
            puts "Exception #{e}\n"
            puts "failed to move #{redmine_src} to #{path} (copy failed or target folder could not be created\n"
          end
          puts "Local file found #{redmine_src} will be moved to #{path}\n"
        else
          begin
            unless file.ftpfileexists?
              # logger.debug "File not in FTP."
              FileUtils.mkdir_p(File.dirname(path)) unless File.exists? File.dirname(path)
              FileUtils.copy_entry(redmine_src,path,true)
              move_count += 1
            end
            FileUtils.rm redmine_src
            remove_count += 1
          rescue Exception => e
            puts "Exception #{e}\n"
            puts "failed to move #{redmine_src} to #{path} (copy failed or target folder could not be created\n"
          end
        end
      end
    end
    ret = { :db_count => db_count, :nofile_count => nofile_count, :move_count => move_count, :remove_count => remove_count }
    puts "Total Files : #{ret[:db_count]}\nFiles not found : #{ret[:nofile_count]}\nFiles to be moved : #{ret[:move_count]}\nFiles Deleted : #{ret[:remove_count]}\n"
  end

  desc  <<-END_DESC
  Move attachments from APP Server to the FTP File server.
Example:
  rake fileserver:move_attachments file_server=[1] RAILS_ENV="production"
END_DESC
  task :move_attachments => :environment do
    file_server_id = ENV['file_server']
    abort("file_server not specified.") if file_server_id.nil? || file_server_id.to_i > 0

    files_server = FileServer.find(file_server_id)
    project_ids = files_server.project_ids
    abort("No Project files to move.") if project_ids.size > 0

    # Get list of file names from the redmine storage.
    search_path = Attachment.storage_path || './files'
    files = Dir["#{search_path}/**/*"]

    disk_filenames = []
    disk_filenames_path = {}
    files.each do |f_path|
      next if File.directory?(f_path)
      f_name = File.basename("#{f_path}")
      disk_filenames << f_name
      disk_filenames_path[f_name] = f_path
    end

    db_count   = 0
    nofile_count = 0
    move_count = 0
    remove_count = 0
    Attachment.where("file_server_id is NULL and disk_filename in (?)", disk_filenames ).all.find_in_batches( batch_size: 1000, start: 0 ) do |batch|
      batch.each do |file|
        # Check if the file is part of the project
        db_count += 1
        if file.container.respond_to?(:project_id) && project_ids.include?(file.container.project_id)
          file.file_server_id = file_server_id
        elsif file.container.class.name == "Project" && project_ids.include?(file.container.id)
          file.file_server_id = file_server_id
        else
          nofile_count += 1
          next
        end

        if file.file_server_id.present?
          file.save
          # File.delete(diskfile) if disk_directory == path && gproject.file_server_id.present? && File.exist?(diskfile) && ftpfileexists?
          move_count += 1
        end
      end
    end
    ret = { :db_count => db_count, :nofile_count => nofile_count, :move_count => move_count }
    puts "Total Files : #{ret[:db_count]}\nFiles not moved : #{ret[:nofile_count]}\nFiles moved : #{ret[:move_count]}\nFiles Deleted : #{ret[:remove_count]}\n"
  end

desc <<-END_DESC
Copy files from redmine storage folder to a target external folder

Example:
  rake fileserver:move_files_out projects="1,2,3" [tracker=12] target=/tmp/REDMINE action=list|move|copy|update fileserverid=1 RAILS_ENV="production"
  project: id of project owning files to move
  tracker: id of only tracker whose files must be moved, optional, if undefined all trackers in project are considered
  target : path of directory where files must be moved
  action : if 'list', files to be moved/copied are just listed
           if 'move', files will be removed from redmine files folder after the copy
           if 'copy', files are just copied and not removed from redmine files folder
           if 'update' the attachment is updated with the file server reference.

Procedure to migrate a project from local redmine folder to FTP server:
  1/ Activate FTP server for project in Redmine console
  2/ Copy files to temporary folder by running script in 'copy' mode
  3/ Copy files from temporary to FTP folder (use scp -p -r)
  4/ Update the attachments by running the script in 'update' mode.
  5/ Remove files from local redmine folder by running script in 'move' mode
  6/ Delete temporary folder

END_DESC

  task :move_files_out => :environment do
    target = ENV['target']
    abort("Target folder not specified.") if target.nil?
    project_ids = ENV['projects']
    abort("Source project id not specified.") if project_ids.nil?
    project_id = project_ids.split(",").map(&:to_i)
    action = ENV['action']
    abort("Action needs to be specified of one of them -> list, move or copy.") if action.nil? || !(["list","move","copy","update"].include? action)
    if action == "update"
      fileserverid = ENV['fileserverid'] || nil
      abort("Fileserver id needs to be specified for update action.") if fileserverid.nil? || fileserverid.to_i < 0
      abort("Fileserver not found for id.") if FileServer.find_by_id(fileserverid.to_i).nil?
    end
    tracker_id = ENV['tracker']

    # files = Attachment.find(:all, :include => [:container]);
    db_count   = 0
    file_count = 0
    copy_count = 0
    del_count  = 0
    update_count  = 0
    Attachment.includes(:container).all.find_in_batches(batch_size: 1000, start: 0 ) do |batch|
      batch.each do |file|
        next if !file.file_server_id.nil? && action == "update"
        next if file.project.nil? || !project_id.include?(file.project.id)
        issue = file.container
        next if !tracker_id.nil? && issue.tracker_id != tracker_id.to_i
        db_count += 1

        src = file.diskfile
        if !File.exists? src
          puts "file not found: #{file.filename} ticket #{issue.id}"
          next
        end
        file_count +=1

        if file.container_type == "Issue"
          diskdir = file.container.alien_files_folder_url(false)
        else
          diskdir = file.getpathforothers(file.project)
        end

        path = "#{target}/#{diskdir}"

        if action == 'list'
          puts "#{src} to be moved to #{path}"
        elsif action == 'update'
          Attachment.where(:id => file.id).update_all(:disk_directory => diskdir, :file_server_id => fileserverid)
          update_count += 1
        else
          begin
            FileUtils.mkdir_p(path) unless File.exists? path
            FileUtils.copy_entry(src,"#{path}/#{file.disk_filename}",true)
            copy_count += 1
            if action == 'move'
              begin
                FileUtils.rm(src)
                del_count += 1
              rescue
              end
            end
          rescue
            puts "failed to copy #{src} in #{path} (copy failed or target folder could not be created\n"
          end
        end
      end
    end
    puts "in database: #{db_count}\nfound\t:\t#{file_count}\ncopied\t:\t#{copy_count}\ndeleted\t:\t#{del_count}\nupdated\t:\t#{update_count}\n"
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

    attachment = Attachment.find_by_disk_filename(source_name)
    attachment = Attachment.find_by_filename(source_name) if attachment.nil?

    abort("Attachment not found") if attachment.nil?

    attachment.file_server_id = project.file_server_id
    attachment.save
  end
end
