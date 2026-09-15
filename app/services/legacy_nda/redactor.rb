module LegacyNda
  class Redactor
    RECIPIENT_BLOCK = /Recipient information.*?(?=This Mutual Non-Disclosure Agreement)/mi
    AGREED_BLOCK = /^\s*AGREED\s*$.*\z/mi
    EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/
    LABELLED_FIELD = /^\s*(Full name|Printed Name|Email|Date)\s*:.*$/i

    def self.call(body)
      body.to_s
        .sub(RECIPIENT_BLOCK, "")
        .sub(AGREED_BLOCK, "")
        .gsub(LABELLED_FIELD, "")
        .gsub(EMAIL, "")
    end
  end
end
