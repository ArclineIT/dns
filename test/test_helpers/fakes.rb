# Answers DNS questions from a table instead of the network.
#   FakeQuery.new("1.1.1.1" => [ "203.1.113.42" ], "9.9.9.9" => :timeout)
class FakeQuery
  Answer = DnsQuery::Answer
  attr_reader :asked

  # String keys given bare arrive as keywords, hence **more.
  def initialize(table = {}, ttl: 300, **more, &block)
    @table = table.merge(more)
    @ttl = ttl
    @block = block
    @asked = Queue.new
  end

  def call(server, name, type, **)
    asked << [ server, name, type ]
    value = @block ? @block.call(server, name, type) : @table[server]

    case value
    when Array then value.empty? ? self.class.empty : Answer.new(status: "answer", records: value.sort, ttl: @ttl, detail: nil)
    when :nxdomain then Answer.new(status: "nxdomain", records: [], ttl: nil, detail: "no such domain")
    when :timeout, nil then Answer.new(status: "timeout", records: [], ttl: nil, detail: "no response in 3s")
    else value
    end
  end

  def self.empty = Answer.new(status: "empty", records: [], ttl: nil, detail: "no record")
end
