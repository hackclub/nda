class PledgeScript
  BODY = [
    "I understand I may be given access to private data, confidential information, or elevated access to Hack Club systems like Slack.",
    "With great power comes great responsibility. I swear that I will uphold this responsibility.",
    "I will keep private information private, I will always act responsibly with privileged access and permissions, and I will do my best to be a model member of Hack Club."
  ].freeze

  def self.for(user)
    <<~SCRIPT
      My name is #{user.legal_first_name} #{user.legal_last_name}. I am #{user.age} years old.
      I currently live in #{user.location_for_pledge}.
      #{BODY.join("\n")}
    SCRIPT
  end
end
