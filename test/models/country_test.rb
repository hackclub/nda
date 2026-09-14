require "test_helper"

class CountryTest < ActiveSupport::TestCase
  test "lists ISO 3166-1 countries by name with their alpha-2 code" do
    assert_equal "United States", Country::ALL["US"]
    assert_equal "United Kingdom", Country::ALL["GB"]
    assert_includes Country::NAMES, "Japan"
    assert_equal Country::ALL.size, Country::NAMES.size
  end

  test "sorts names that start with an accent where a reader expects them" do
    names = Country::NAMES
    assert_operator names.index("Åland Islands"), :<, names.index("Albania")
  end

  test "carries the code each option needs for its flag" do
    name, value, attributes = Country.select_options.find { |option| option.first == "Japan" }
    assert_equal "Japan", name
    assert_equal "Japan", value
    assert_equal({ data: { code: "jp" } }, attributes)
  end
end
