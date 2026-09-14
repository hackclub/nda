require "net/http"

namespace :flags do
  SOURCE = "https://raw.githubusercontent.com/jdecked/twemoji/v17.0.3/assets/svg".freeze
  DIRECTORY = Rails.root.join("app/javascript/flags")

  desc "Vendor the Twemoji flag SVGs for every country in Country::ALL"
  task fetch: :environment do
    DIRECTORY.mkpath
    wanted = Country::ALL.keys.to_h { |code| [ code.chars.map { |letter| (0x1f1e6 + letter.ord - 65).to_s(16) }.join("-"), code ] }

    written = wanted.keys.each_slice(16).sum do |batch|
      batch.map { |name| Thread.new { [ name, fetch_flag(name) ] } }.map(&:value).count do |name, svg|
        DIRECTORY.join("#{name}.svg").binwrite(svg) if svg
        abort "No flag for #{wanted[name]} (#{name}) at #{SOURCE}." unless svg
        true
      end
    end

    (DIRECTORY.glob("*.svg").map { |path| path.basename(".svg").to_s } - wanted.keys).each do |stale|
      DIRECTORY.join("#{stale}.svg").delete
      puts "Removed #{stale}.svg; no country uses it."
    end
    puts "Vendored #{written} flags from #{SOURCE}."
  end

  def fetch_flag(name)
    response = Net::HTTP.get_response(URI("#{SOURCE}/#{name}.svg"))
    response.body if response.is_a?(Net::HTTPSuccess)
  end
end
