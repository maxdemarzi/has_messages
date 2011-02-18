module HasUuid
  def set_uuid
    self.id = UUIDTools::UUID.timestamp_create.to_s
  end

end

class ActiveRecord::Base
  def self.has_uuid
    include HasUuid
    before_create :set_uuid
  end
end
