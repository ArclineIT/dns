require "test_helper"

class AuthoritativeServersTest < ActiveSupport::TestCase
  test "walks up to the zone that has nameservers and resolves them" do
    query = FakeQuery.new do |_server, name, type|
      case [ name, type ]
      when [ "www.shop.example.com", "NS" ], [ "shop.example.com", "NS" ] then []
      when [ "example.com", "NS" ] then %w[ ns2.host.test ns1.host.test ]
      when [ "ns1.host.test", "A" ] then [ "203.1.113.1" ]
      when [ "ns2.host.test", "A" ] then [ "203.1.113.2" ]
      end
    end
    servers = AuthoritativeServers.new(query: query).call("www.shop.example.com")

    assert_equal [ [ "203.1.113.1", "ns1.host.test" ], [ "203.1.113.2", "ns2.host.test" ] ], servers.map { |s| [ s.address, s.label ] }
    assert servers.all?(&:authoritative)
  end

  test "skips nameservers that do not resolve or resolve to a private address" do
    query = FakeQuery.new do |_server, name, type|
      { [ "example.com", "NS" ] => %w[ ns1.host.test ns2.host.test ns3.host.test ], [ "ns1.host.test", "A" ] => [ "10.0.0.53" ],
        [ "ns2.host.test", "A" ] => [], [ "ns3.host.test", "A" ] => [ "203.1.113.3" ] }[[ name, type ]]
    end

    assert_equal [ "203.1.113.3" ], AuthoritativeServers.new(query: query).call("example.com").map(&:address)
  end

  test "a name with no nameservers anywhere gives none, without asking about the bare TLD" do
    query = FakeQuery.new { |*| [] }

    assert_empty AuthoritativeServers.new(query: query).call("a.b.example.com")
    asked = Array.new(query.asked.size) { query.asked.pop }.map(&:second)
    assert_equal %w[ a.b.example.com b.example.com example.com ], asked
  end
end
