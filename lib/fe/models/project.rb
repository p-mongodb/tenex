class Project
  include Mongoid::Document

  field :name, type: String
  field :slug, type: String

  has_one :repo

  before_validation :set_slug, on: :create

  private

  def set_slug
    if slug.nil?
      self.slug = name.gsub(/[^\w]/, '-').gsub(/-+/, '-').sub(/^-/, '').sub(/-$/, '')
    end
  end

  validates_presence_of :slug
  validates_uniqueness_of :slug
end
