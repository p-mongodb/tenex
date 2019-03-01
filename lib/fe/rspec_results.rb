class RspecResults
  def initialize(content)
    @payload = JSON.parse(content)
  end
end
