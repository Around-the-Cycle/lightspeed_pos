require_relative 'resource'

module Lightspeed
  # https://developers.lightspeedhq.com/retail/endpoints/Serialized/
  class Serialized < Lightspeed::Resource
    fields(
      serializedID: :id,
      colorName: :string,
      sizeName: :string,
      serial: :string,
      description: :string,
      itemID: :integer,
      saleLineID: :integer,
      customerID: :integer
    )

    # def resource_name
      # "Serialized"
    # end
  end
end
