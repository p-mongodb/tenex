class ArtifactFileInfo
  def initialize(name, size:)
    @name = name
    @size = size
  end

  attr_reader :name, :size
end
