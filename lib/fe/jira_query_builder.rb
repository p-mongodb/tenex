class JiraQueryBuilder
  PROJECT_ALIASES = {
    'lmc' => 'libmongocrypt',
  }.freeze

  PROJECTS = %w(
    ruby mongoid server
  ).freeze

  COMPONENTS = %w(
    bson
  ).freeze

  def initialize(query)
    @smart_query = query
  end

  attr_reader :smart_query

  def expanded_query
    query = []
    parts = smart_query.split(/\s+/)
    until parts.empty?
      part = parts.shift
      dpart = part.downcase
      if dpart == 'and'
        query << parts.join(' ')
        parts = []
      elsif dpart == 'rme'
        query << 'reporter = currentUser()'
      elsif PROJECT_ALIASES.key?(dpart)
        query << "project in (#{PROJECT_ALIASES[dpart]})"
      elsif PROJECTS.include?(dpart)
        query << "project in (#{part})"
      elsif %w(open).include?(dpart)
        query << "resolution in (unresolved)"
      elsif COMPONENTS.include?(dpart)
        query << "component in (#{part})"
      elsif parts.length > 0 &&
        (bits = [dpart, parts.first.downcase]) == %w(spec compliance)
      then
        parts.shift
        component = bits.join(' ')
        query << "component in ('#{component}')"
      else
        text = ([part] + parts).join(' ')
        query << %Q,(summary ~ "#{text}" or description ~ "#{text}"),
        parts = []
      end
    end
    query = query.join(' and ')
  end
end
