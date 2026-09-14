module Country
  ALL = ISO3166::Country.all
    .to_h { |country| [ country.alpha2, country.common_name.presence || country.iso_short_name ] }
    .sort_by { |_code, name| ActiveSupport::Inflector.transliterate(name) }
    .to_h
    .freeze

  NAMES = ALL.values.freeze

  def self.select_options
    ALL.map { |code, name| [ name, name, { data: { code: code.downcase } } ] }
  end
end
