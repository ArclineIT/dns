require "resolv"
require "socket"

# Asks one resolver one question, directly over UDP (TCP if the answer was
# truncated). Unlike Ruby's resolver this tells a timeout apart from "no such
# record", and reports each record's TTL.
class DnsQuery
  TIMEOUT = 3
  TYPES = {
    "A" => Resolv::DNS::Resource::IN::A, "AAAA" => Resolv::DNS::Resource::IN::AAAA, "CNAME" => Resolv::DNS::Resource::IN::CNAME,
    "MX" => Resolv::DNS::Resource::IN::MX, "TXT" => Resolv::DNS::Resource::IN::TXT, "NS" => Resolv::DNS::Resource::IN::NS,
    "SOA" => Resolv::DNS::Resource::IN::SOA
  }.freeze

  # status is "answer", "empty" (the name exists but has no such record),
  # "nxdomain", "timeout" or "error".
  Answer = Data.define(:status, :records, :ttl, :detail) do
    def responded? = status.in?(%w[ answer empty nxdomain ])
  end

  def self.call(...)
    new(...).call
  end

  def initialize(server, name, type, timeout: TIMEOUT)
    @server = server
    @name = name
    @type = TYPES.fetch(type)
    @timeout = timeout
  end

  def call
    reply = exchange(:udp)
    reply = exchange(:tcp) if reply.tc == 1
    interpret(reply)
  rescue IO::TimeoutError, Timeout::Error
    Answer.new(status: "timeout", records: [], ttl: nil, detail: "no response in #{@timeout}s")
  rescue SystemCallError, SocketError, IOError, Resolv::DNS::DecodeError => e
    Answer.new(status: "error", records: [], ttl: nil, detail: e.message.truncate(80))
  end

  private
    def interpret(reply)
      case reply.rcode
      when Resolv::DNS::RCode::NXDomain then Answer.new(status: "nxdomain", records: [], ttl: nil, detail: "no such domain")
      when Resolv::DNS::RCode::NoError
        answers = reply.answer.select { |_name, _ttl, resource| resource.is_a?(@type) }
        return Answer.new(status: "empty", records: [], ttl: nil, detail: "no record") if answers.empty?

        Answer.new(status: "answer", records: answers.map { |_name, _ttl, resource| format_record(resource) }.sort, ttl: answers.map { |_name, ttl, _| ttl }.min, detail: nil)
      else
        Answer.new(status: "error", records: [], ttl: nil, detail: "resolver answered rcode #{reply.rcode}")
      end
    end

    def format_record(resource)
      case resource
      when Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA then resource.address.to_s.downcase
      when Resolv::DNS::Resource::IN::MX then "#{resource.preference} #{resource.exchange.to_s.downcase}"
      when Resolv::DNS::Resource::IN::TXT then resource.strings.join.inspect
      when Resolv::DNS::Resource::IN::SOA then "#{resource.mname.to_s.downcase} #{resource.rname.to_s.downcase} #{resource.serial}"
      else resource.name.to_s.downcase
      end
    end

    def request
      @request ||= Resolv::DNS::Message.new(SecureRandom.random_number(0x10000)).tap do |message|
        message.rd = 1
        message.add_question(Resolv::DNS::Name.create("#{@name}."), @type)
      end
    end

    def exchange(transport)
      data = transport == :udp ? over_udp(request.encode) : over_tcp(request.encode)
      reply = Resolv::DNS::Message.decode(data)
      raise Resolv::DNS::DecodeError, "reply does not match the question" unless reply.id == request.id
      reply
    end

    def over_udp(payload)
      socket = UDPSocket.new(@server.include?(":") ? Socket::AF_INET6 : Socket::AF_INET)
      socket.connect(@server, 53)
      socket.send(payload, 0)
      raise IO::TimeoutError unless socket.wait_readable(@timeout)
      socket.recv(4096)
    ensure
      socket&.close
    end

    def over_tcp(payload)
      socket = TCPSocket.new(@server, 53, connect_timeout: @timeout)
      socket.timeout = @timeout
      socket.write([ payload.bytesize ].pack("n") + payload)
      length = socket.read(2).to_s.unpack1("n") or raise IOError, "resolver closed the connection"
      socket.read(length)
    ensure
      socket&.close
    end
end
