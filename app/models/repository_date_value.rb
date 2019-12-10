# frozen_string_literal: true

class RepositoryDateValue < RepositoryDateTimeValueBase
  def data_changed?(new_data)
    new_time = Time.zone.parse(new_data)
    new_time.to_date != data.to_date
  end

  def formatted
    super(:full_date)
  end

  def self.new_with_payload(payload, attributes)
    value = new(attributes)
    value.data = Time.zone.parse(payload)
    value
  end
end
