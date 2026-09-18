require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Nda
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    config.generators do |g|
      g.helper false
      g.assets false
      g.system_tests nil
    end

    # Identity videos are never transformed, and SSE-C objects cannot be analyzed by Active Storage.
    config.active_storage.variant_processor = :disabled
    config.active_storage.analyzers = []
    config.active_storage.draw_routes = false
  end
end
