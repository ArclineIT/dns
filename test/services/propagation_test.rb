require "test_helper"

class PropagationTest < ActiveSupport::TestCase
  RESOLVERS = Resolver.public_list

  test "resolvers that match the majority are ok and the rest differ" do
    table = RESOLVERS.to_h { |resolver| [ resolver.address, [ "203.1.113.42" ] ] }.merge("208.67.222.222" => [ "203.1.113.10" ])
    result = Propagation.call("example.com", "A", resolvers: RESOLVERS, query: FakeQuery.new(table))

    assert_equal %w[ ok ok ok ok diff ok ], result.rows.map(&:status)
    assert_equal "5/6 resolvers agree", result.summary
    assert_not result.propagated?
  end

  test "renders the terminal table" do
    table = RESOLVERS.to_h { |resolver| [ resolver.address, [ "203.1.113.42" ] ] }.merge("208.67.222.222" => [ "203.1.113.10" ])
    text = Propagation.call("example.com", "A", resolvers: RESOLVERS, query: FakeQuery.new(table)).to_text

    assert_equal [
      "",
      "  domain   example.com",
      "  type     A",
      "  queried  6 resolvers",
      "",
      "  resolver                  answer        ttl     status",
      "  ────────────────────────  ────────────  ──────  ──────",
      "  1.1.1.1 (Cloudflare)      203.1.113.42  300s    [OK]",
      "  1.0.0.1 (Cloudflare)      203.1.113.42  300s    [OK]",
      "  8.8.8.8 (Google)          203.1.113.42  300s    [OK]",
      "  8.8.4.4 (Google)          203.1.113.42  300s    [OK]",
      "  208.67.222.222 (OpenDNS)  203.1.113.10  300s    [DIFF]",
      "  9.9.9.9 (Quad9)           203.1.113.42  300s    [OK]",
      "",
      "  propagation   5/6 resolvers agree",
      ""
    ].join("\n"), text
  end

  test "record order does not matter, only the set" do
    query = FakeQuery.new("1.1.1.1" => %w[ b.example a.example ], "8.8.8.8" => %w[ a.example b.example ])
    result = Propagation.call("example.com", "NS", resolvers: RESOLVERS.values_at(0, 2), query: query)

    assert result.propagated?
  end

  test "a resolver that does not respond is none and never part of the majority" do
    query = FakeQuery.new("1.1.1.1" => :timeout, "1.0.0.1" => :timeout, "8.8.8.8" => [ "203.1.113.42" ])
    result = Propagation.call("example.com", "A", resolvers: RESOLVERS.first(3), query: query)

    assert_equal %w[ none none ok ], result.rows.map(&:status)
    assert_equal "1/3 resolvers agree", result.summary
    assert_not result.propagated?
  end

  test "agreeing that a record does not exist is still agreement" do
    query = FakeQuery.new("1.1.1.1" => :nxdomain, "1.0.0.1" => :nxdomain, "8.8.8.8" => [ "203.1.113.42" ])
    result = Propagation.call("new.example.com", "A", resolvers: RESOLVERS.first(3), query: query)

    assert_equal %w[ ok ok diff ], result.rows.map(&:status)
    assert_equal "no such domain", result.rows.first.display
  end

  test "an even split sides with the resolver listed first" do
    query = FakeQuery.new("1.1.1.1" => [ "old" ], "8.8.8.8" => [ "new" ])
    result = Propagation.call("example.com", "A", resolvers: RESOLVERS.values_at(0, 2), query: query)

    assert_equal %w[ ok diff ], result.rows.map(&:status)
  end

  test "asks every resolver the same question" do
    query = FakeQuery.new(RESOLVERS.to_h { |resolver| [ resolver.address, [ "x" ] ] })
    Propagation.call("example.com", "TXT", resolvers: RESOLVERS, query: query)

    asked = Array.new(query.asked.size) { query.asked.pop }
    assert_equal RESOLVERS.map { |resolver| [ resolver.address, "example.com", "TXT" ] }.sort, asked.sort
  end

  test "the JSON form lists every resolver" do
    json = Propagation.call("example.com", "A", resolvers: RESOLVERS.first(1), query: FakeQuery.new("1.1.1.1" => [ "203.1.113.42" ])).as_json

    assert_equal [ "example.com", "A", true, 1 ], json.values_at(:domain, :type, :propagated, :queried)
    assert_equal({ resolver: "1.1.1.1", label: "Cloudflare", authoritative: false, status: "ok", answers: [ "203.1.113.42" ], ttl: 300, detail: nil }, json[:resolvers].first)
  end
end
