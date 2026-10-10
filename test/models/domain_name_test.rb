require "test_helper"

class DomainNameTest < ActiveSupport::TestCase
  test "accepts a hostname however it was pasted, including underscore labels" do
    { "example.com" => "example.com", " Example.COM. " => "example.com", "https://www.example.com/path?q=1" => "www.example.com",
      "_dmarc.example.com" => "_dmarc.example.com", "selector1._domainkey.example.com" => "selector1._domainkey.example.com" }.each do |input, expected|
      assert_equal expected, DomainName.parse(input), input
    end
  end

  test "rejects anything that is not a public hostname" do
    [ "", "localhost", "-bad.example.com", "exa mple.com", "example..com", "127.0.0.1", "__x.example.com", "a_b.example.com", nil ].each do |input|
      assert_raises(DomainName::Invalid, input.inspect) { DomainName.parse(input) }
    end
  end
end
