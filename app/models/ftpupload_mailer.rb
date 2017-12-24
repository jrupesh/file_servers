class FtpuploadMailer < Mailer
  def failure_notification(options={})
    recipients = User.active.where(admin: true)
    @message = options[:message]
    @title = options[:title] && l(options[:title])
    @url = options[:url] && (options[:url].is_a?(Hash) ?
                                 url_for(options[:url]) : options[:url])
    mail :to => recipients,
         :subject => "[#{l(:label_ftp_upload)}] #{@title}"
  end
end
