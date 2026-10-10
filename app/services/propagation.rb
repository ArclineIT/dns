# Asks every resolver the same question at once and compares the answers, to
# show how far a DNS change has spread.
class Propagation
  Row = Data.define(:resolver, :answer, :status) do
    def ttl = answer.ttl

    def display
      return answer.detail if answer.records.empty?

      answer.records.join(", ")
    end

    def tag = { "ok" => "[OK]", "diff" => "[DIFF]", "none" => "[NONE]" }.fetch(status)
  end

  Result = Data.define(:domain, :type, :rows, :checked_at) do
    def responded = rows.reject { |row| row.status == "none" }
    def agreeing = rows.count { |row| row.status == "ok" }
    def propagated? = rows.any? && rows.all? { |row| row.status == "ok" }
    def summary = "#{agreeing}/#{rows.size} resolvers agree"

    def as_json(*)
      {
        domain: domain, type: type, propagated: propagated?, agreeing: agreeing, queried: rows.size, checked_at: checked_at.utc.iso8601,
        resolvers: rows.map do |row|
          { resolver: row.resolver.address, label: row.resolver.label, authoritative: row.resolver.authoritative,
            status: row.status, answers: row.answer.records, ttl: row.ttl, detail: row.answer.detail }
        end
      }
    end

    def to_text(color: false)
      paint = ->(row) do
        next row.tag unless color
        "\e[#{{ 'ok' => 32, 'diff' => 31, 'none' => 33 }.fetch(row.status)}m#{row.tag}\e[0m"
      end
      names = rows.map { |row| row.resolver.to_s }
      answers = rows.map(&:display)
      name_width = [ names.map(&:length).max.to_i, 8 ].max
      answer_width = [ answers.map(&:length).max.to_i, 6 ].max.clamp(6, 60)

      lines = [ "", "  domain   #{domain}", "  type     #{type}", "  queried  #{rows.size} resolvers", "",
                format("  %-#{name_width}s  %-#{answer_width}s  %-6s  %s", "resolver", "answer", "ttl", "status"),
                "  #{'─' * name_width}  #{'─' * answer_width}  #{'─' * 6}  #{'─' * 6}" ]
      rows.each_with_index do |row, index|
        ttl = row.ttl ? "#{row.ttl}s" : "—"
        lines << format("  %-#{name_width}s  %-#{answer_width}s  %-6s  %s", names[index], answers[index].truncate(answer_width), ttl, paint.call(row))
      end
      [ *lines, "", "  propagation   #{summary}", "" ].join("\n")
    end
  end

  def self.call(...)
    new(...).call
  end

  def initialize(domain, type, resolvers:, query: DnsQuery)
    @domain = domain
    @type = type
    @resolvers = resolvers
    @query = query
  end

  def call
    answers = @resolvers.map { |resolver| Thread.new { @query.call(resolver.address, @domain, @type) } }.map(&:value)
    majority = majority_of(answers)

    rows = @resolvers.zip(answers).map do |resolver, answer|
      status = if !answer.responded? then "none"
      elsif signature(answer) == majority then "ok"
      else "diff"
      end
      Row.new(resolver: resolver, answer: answer, status: status)
    end
    Result.new(domain: @domain, type: @type, rows: rows, checked_at: Time.current)
  end

  private
    # What an answer says, ignoring TTLs. "No such record" is an answer too.
    def signature(answer)
      answer.records.presence || answer.status
    end

    # The most common answer among resolvers that responded. On a tie the one
    # given first wins, and the public resolvers are listed first.
    def majority_of(answers)
      responded = answers.select(&:responded?).map { |answer| signature(answer) }
      responded.tally.max_by { |value, count| [ count, -responded.index(value) ] }&.first
    end
end
