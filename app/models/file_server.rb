class FileServer < ActiveRecord::Base
  unloadable
  has_many :projects, :dependent => :nullify
  has_many :attachment, :dependent => :nullify
  
  PROTOCOL_FTP = 0
  
  PROTOCOLS = { PROTOCOL_FTP => { :name => "ftp", :label => :label_file_server_ftp, :order => 1}
          }.freeze

  validates_presence_of :name
  validates_length_of :name, :maximum => 50
  validates_presence_of :address
  validates_length_of :address, :maximum => 120
  validates_numericality_of :port, :allow_nil => true
  validates_length_of :root, :maximum => 120
  validates_length_of :login, :maximum => 40
  validates_length_of :password, :maximum => 40
  validates_inclusion_of :protocol, :in => PROTOCOLS.keys

  require 'net/ftp'
  require 'stringio'

  def initialize(attributes=nil, *args)
    super
    if new_record?
      # set default values for new records only
      self.protocol ||= PROTOCOLS.keys[0]
    end
  end

  def to_s; self.name end

  def type_name
    PROTOCOLS[self.protocol][:name]
  end

  def type_label
    l(PROTOCOLS[self.protocol ||= PROTOCOLS.keys[0]][:label])
  end

  def url_for(relative_path,full,public=false,root_included=false)
    url = []
    if full
      ftp_credentials = ""
      ftp_credentials += "ftp://"
      ftp_credentials += self.login if self.login
      ftp_credentials += ":" + self.password if self.password && !public
      ftp_credentials += "@" if self.login || (self.password && !public)
      ftp_credentials += self.address
      ftp_credentials += ":" + self.port.to_s unless self.port.nil?
      url << ftp_credentials
    end 
    url << self.root if (!self.root.blank? && !root_included)
    url << relative_path
    logger.debug("url_for url -- #{url} ---")
    url.compact.join('/')
  end

  def make_directory(path)
    ftp = ftp_connection
    return if ftp.nil?

    ret = false
    begin
      ftp.mkdir path
      ftp.close
      ret = true
    rescue
    end
    ret
  end

  def scan_directory(path,attched_files,create_it=false)
    ftp = ftp_connection
    return if ftp.nil?

    # files = nil
    files = {}
    begin
      if create_it
        begin
          ftp.mkdir path
        rescue
        end
      end
      
      ftp.chdir path
      ftp.passive = true
      # files = ftp.nlst

      remote_files = ftp.nlst
      remote_files.each do |file|
        if !attched_files.include? file
          remote_size = ftp.size(file)
          files[file] = remote_size
        else
          files[file] = 0 # Skip getting file size
        end
      end
      ftp.close
    rescue
    end
    files
  end

  def upload_file(source_file_path, target_directory_path, target_file_name)
    ftp = ftp_connection
    return if ftp.nil?

    ret = false
    begin
      begin
        ftp.mkdir target_directory_path
      rescue
      end
      ftp.chdir target_directory_path
      ftp.passive = true
      ftp.putbinaryfile source_file_path,target_file_name
      ftp.close
      ret = true
    rescue
    end
    ret
  end

  def delete_file(file_directory, file_name)
    ftp = ftp_connection
    return if ftp.nil?

    ret = false
    begin
      ftp.chdir file_directory
      ftp.delete file_name
      ftp.close
      ret = true
    rescue
    end
    ret
  end

  def self.crypt_password(pwd)
    pwd.nil? ? "" : pwd
  end

  def decrypted_password
    self.password
  end

  def puttextcontent(content, remotefile)
    ftp = ftp_connection
    return if ftp.nil?
    ret = false

    f = StringIO.new(content)
    begin
      ftp.storbinary("STOR " + remotefile, f, 8192)
    ensure
      f.close
      ret = true
    end
    ret
  end

  def move_file_to_dir(source_file_path,target_file_path)
    ftp = ftp_connection
    return if ftp.nil?
    ret = false
    begin
      logger.debug("move_file_to_dir source_file_path #{source_file_path} --target_file_path - #{target_file_path}")
      ftp.rename(source_file_path,target_file_path)
      ftp.close
      ret = true
    rescue
      logger.debug("move_file_to_dir ERROR")
    end
    ret
  end

  def readftpFile(ftpremotefile, localfile=nil)
    ftp = ftp_connection
    return if ftp.nil?

    ret = ""
    begin
      ret = ftp.getbinaryfile(ftpremotefile, localfile)
      ftp.close
    rescue
    end
    ret
  end


  def ftp_file_exists?(file_directory, filename)
    ftp = ftp_connection
    return if ftp.nil?

    ret = false
    begin
      ftp.chdir(file_directory)
      ret = true if not ftp.nlst(filename).empty?
      ftp.close
    rescue
    end
    ret
  end

  private
    def ftp_connection
      ftp = nil
      begin
        ftp = Net::FTP.new
        begin
          Timeout.timeout(5) do
            if self.port.nil?
              ftp.connect self.address
            else
              ftp.connect self.address, self.port
            end
          end
          ftp.login self.login, self.decrypted_password
        rescue Timeout::Error => e
          ftp = nil
        end
      rescue
        ftp = nil
      end
      ftp
    end
end
