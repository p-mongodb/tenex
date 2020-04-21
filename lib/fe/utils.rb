module Digest
  autoload :MD5, 'digest/md5'
end

module Utils
  module_function def md5(str)
    Digest::MD5.new.update(str).hexdigest
  end
end
