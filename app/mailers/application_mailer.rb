class ApplicationMailer < ActionMailer::Base
  default from: CompanyInfo.no_reply
  layout 'mailer'
end
