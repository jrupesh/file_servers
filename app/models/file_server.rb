class FileServer < ActiveRecord::Base
  unloadable
  has_many :projects, :dependent => :nullify
  
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

  def to_s; self.name end

  def type_name
    PROTOCOLS[self.protocol][:name]
  end

  def type_label
    l(PROTOCOLS[self.protocol][:label])
  end

  def url_for(relative_path,full,public=false)
    if full
      url  = "ftp://"
      url += self.login if self.login
      url += ":" + self.password if self.password && !public
      url += "@" if self.login || (self.password && !public)
      url += self.address
      url += ":" + self.port.to_s unless self.port.nil?
    else
      url = ""
    end 
    url += "/" + self.root + "/"
    url += relative_path
    url
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

  def scan_directory(path,create_it=false)
    ftp = ftp_connection
    return if ftp.nil?

    files = nil
    begin
      if create_it
        begin
          ftp.mkdir path
        rescue
        end
      end
      
      ftp.chdir path
      ftp.passive = true
      files = ftp.nlst
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
  
  def project_path_name(p)
    n = ""
    begin
      n = n.blank? ? p.name : p.name + " >> " + n
      p = p.parent
    end while p
    n
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
