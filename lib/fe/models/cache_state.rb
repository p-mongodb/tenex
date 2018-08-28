class CacheState
  include Mongoid::Document

  field :distros_updated_at, type: Time
  field :keys_updated_at, type: Time

  def distros_ok?
    distros_updated_at && distros_updated_at > Time.now - 1.day
  end

  def keys_ok?
    keys_updated_at && keys_updated_at > Time.now - 1.day
  end
end
