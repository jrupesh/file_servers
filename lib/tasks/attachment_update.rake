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

desc <<-END_DESC
Copy files from redmine storage folder to a target external folder

Example:
  rake fileserver:move_files_out project=1 [tracker=12] target=/tmp/REDMINE action=list|move|copy RAILS_ENV="production"
  project: id of project owning files to move
  tracker: id of only tracker whose files must be moved, optional, if undefined all trackers in project are considered
  target : path of directory where files must be moved
  action : if 'list', files to be moved/copied are just listed
           if 'move', files will be removed from redmine files folder after the copy
           if 'copy', files are just copied and not removed from redmine files folder

Procedure to migrate a project from local redmine folder to FTP server:
  1/ Copy files to temporary folder by running script in 'copy' mode
  2/ Copy files from temporary to FTP folder (use scp -p -r)
  3/ Activate FTP server for project in Redmine console
  4/ Remove files from local redmine folder by running script in 'move' mode
  5/ Delete temporary folder
END_DESC

  task :move_files_out => :environment do
    target = ENV['target']
    abort("Target folder not specified.") if target.nil?
    project_id = ENV['project']
    abort("Source project id not specified.") if project_id.nil?
    action = ENV['action']
    abort("Action needs to be specified of one of them -> list, move or copy.") if action.nil? || !(["list","move","copy"].include? action)
    tracker_id = ENV['tracker']

    # files = Attachment.find(:all, :include => [:container]);
    db_count   = 0
    file_count = 0
    copy_count = 0
    del_count  = 0
    Attachment.includes(:container).all.find_in_batches(batch_size: 1000, start: 0 ) do |batch|
      batch.each do |file|
        # next if file.container_type != "Issue"
        next if !file.file_server_id.nil?
        next if file.project.nil? || file.project.id != project_id.to_i
        issue = file.container
        next if !tracker_id.nil? && issue.tracker_id != tracker_id.to_i
        db_count += 1

        # src = "#{RAILS_ROOT}/files/#{file.disk_filename}"
        src = file.diskfile
        if !File.exists? src
          puts "file not found: #{file.filename} ticket #{issue.id}"
          next
        end
        file_count +=1

        if file.container_type == "Issue"
          path = container.alien_files_folder_url(false)
        else
          path = file.getpathforothers(file.project)
        end

        if action == 'list'
          puts "#{src} to be moved to #{path}"
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
    puts "in database: #{db_count}\nfound      : #{file_count}\ncopied     :#{copy_count}\ndeleted    : #{del_count}\n"
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
