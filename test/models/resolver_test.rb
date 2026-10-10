require "test_helper"

class ResolverTest < ActiveSupport::TestCase
  test "the public list covers Cloudflare, Google, OpenDNS and Quad9" do
    assert_equal %w[ 1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 208.67.222.222 9.9.9.9 ], Resolver.public_list.map(&:address)
    assert_equal "1.1.1.1 (Cloudflare)", Resolver.public_list.first.to_s
  end

  test "parses a custom list, labelling the ones it knows" do
    resolvers = Resolver.parse_list(" 8.8.8.8, 4.2.2.2  2606:4700:4700::1111,8.8.8.8 ")

    assert_equal %w[ 8.8.8.8 4.2.2.2 2606:4700:4700::1111 ], resolvers.map(&:address)
    assert_equal [ "8.8.8.8 (Google)", "4.2.2.2" ], resolvers.first(2).map(&:to_s)
  end

  test "refuses private addresses, hostnames and long lists" do
    [ "10.0.0.53", "8.8.8.8,192.168.1.1", "127.0.0.1", "169.254.169.254", "dns.google", "::1" ].each do |input|
      assert_raises(Resolver::Invalid, input) { Resolver.parse_list(input) }
    end
    assert_raises(Resolver::Invalid) { Resolver.parse_list((1..13).map { |n| "8.8.8.#{n}" }.join(",")) }
  end
end
