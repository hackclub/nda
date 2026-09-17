class PledgeScript
  BODY = [
    "I understand that I may be granted access to confidential information, private data, or elevated access to Hack Club systems like Slack.",
    "I understand that I am serving as a volunteer and not as an employee or independent contractor of Hack Club - unless stated otherwise.",
    "With great power comes great responsibility. I promise to protect confidential information, use my access responsibly, and never access or share information except as necessary for my authorized activities.",
    "I will keep private information confidential, I will always act responsibly with any privileged access or permissions I receive, and do my best to be a model member of Hack Club."
  ].freeze

  def self.for(user)
    <<~SCRIPT
      My name is #{user.legal_first_name} #{user.legal_last_name}. I am #{user.age} years old.
      I currently live in #{user.location_for_pledge}.
      #{BODY.join("\n")}
    SCRIPT
  end
end
