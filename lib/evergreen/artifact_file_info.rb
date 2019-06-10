class ArtifactFileInfo
  def initialize(name, path)
    @name = name
    stat = File.stat(path)
    @size = stat.size
  end

  attr_reader :name, :size
end
