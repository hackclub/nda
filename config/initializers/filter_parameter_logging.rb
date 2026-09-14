Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :birthdate, :address, :postal, :city, :region, :country, :name, :identity_video, :transcript, :user_agent
]
