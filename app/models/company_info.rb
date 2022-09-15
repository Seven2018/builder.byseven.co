class CompanyInfo
  class << self
    def dev_email
      ENV['DEV_MAIL'].presence || 'william.favreau@byseven.co, brice.chapuis@byseven.co'
    end

    def no_reply
      'no-reply@byseven.co'
    end

    def mailer_from
      no_reply
    end
  end
end
