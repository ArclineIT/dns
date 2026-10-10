require "test_helper"

class DnsQueryTest < ActiveSupport::TestCase
  IN = Resolv::DNS::Resource::IN

  test "returns the records of the asked type, sorted, with the lowest TTL" do
    answer = query("A") do |reply|
      reply.add_answer("www.example.test.", 300, IN::CNAME.new(Resolv::DNS::Name.create("example.test.")))
      reply.add_answer("example.test.", 120, IN::A.new("203.1.113.9"))
      reply.add_answer("example.test.", 60, IN::A.new("203.1.113.10"))
    end

    assert_equal "answer", answer.status
    assert_equal %w[ 203.1.113.10 203.1.113.9 ], answer.records
    assert_equal 60, answer.ttl
  end

  test "formats each record type" do
    assert_equal [ "10 mail.example.test" ], query("MX") { |r| r.add_answer("example.test.", 300, IN::MX.new(10, Resolv::DNS::Name.create("Mail.Example.test."))) }.records
    assert_equal [ '"v=spf1 include:_spf.example.test ~all"' ], query("TXT") { |r| r.add_answer("example.test.", 300, IN::TXT.new("v=spf1 include:", "_spf.example.test ~all")) }.records
    assert_equal [ "ns1.example.test" ], query("NS") { |r| r.add_answer("example.test.", 300, IN::NS.new(Resolv::DNS::Name.create("ns1.example.test."))) }.records
    assert_equal [ "2001:db8::1" ], query("AAAA") { |r| r.add_answer("example.test.", 300, IN::AAAA.new("2001:DB8::1")) }.records

    soa = IN::SOA.new(Resolv::DNS::Name.create("ns1.example.test."), Resolv::DNS::Name.create("hostmaster.example.test."), 2026060101, 3600, 600, 86_400, 300)
    assert_equal [ "ns1.example.test hostmaster.example.test 2026060101" ], query("SOA") { |r| r.add_answer("example.test.", 300, soa) }.records
  end

  test "tells a missing record apart from a missing domain" do
    assert_equal "empty", query("MX") { |_reply| }.status

    nxdomain = query("A") { |reply| reply.rcode = Resolv::DNS::RCode::NXDomain }
    assert_equal [ "nxdomain", "no such domain" ], [ nxdomain.status, nxdomain.detail ]
    assert nxdomain.responded?
  end

  test "a refusing resolver is an error, and a silent one a timeout" do
    refused = query("A") { |reply| reply.rcode = Resolv::DNS::RCode::Refused }
    assert_equal "error", refused.status
    assert_not refused.responded?

    silent = UDPSocket.new.tap { |socket| socket.bind("127.0.0.1", 0) }
    answer = on_port(silent.addr[1]) { DnsQuery.call("127.0.0.1", "example.test", "A", timeout: 0.2) }
    assert_equal "timeout", answer.status
    assert_not answer.responded?
  ensure
    silent&.close
  end

  test "a reply to a different question is rejected" do
    answer = query("A", id_offset: 1) { |reply| reply.add_answer("example.test.", 300, IN::A.new("203.1.113.9")) }
    assert_equal "error", answer.status
  end

  private
    # Runs a one-shot UDP resolver that answers with whatever the block builds.
    def query(type, id_offset: 0)
      server = UDPSocket.new
      server.bind("127.0.0.1", 0)
      thread = Thread.new do
        data, sender = server.recvfrom(4096)
        question = Resolv::DNS::Message.decode(data)
        reply = Resolv::DNS::Message.new((question.id + id_offset) % 0x10000)
        reply.qr = 1
        question.each_question { |name, typeclass| reply.add_question(name, typeclass) }
        yield reply
        server.send(reply.encode, 0, sender[3], sender[1])
      end

      on_port(server.addr[1]) { DnsQuery.call("127.0.0.1", "example.test", type, timeout: 2) }
    ensure
      thread&.join(2)
      server&.close
    end

    # DnsQuery always talks to port 53; send it to the test server instead.
    def on_port(port)
      original = UDPSocket.instance_method(:connect)
      UDPSocket.define_method(:connect) { |host, _port| original.bind_call(self, host, port) }
      yield
    ensure
      UDPSocket.define_method(:connect, original)
    end
end
