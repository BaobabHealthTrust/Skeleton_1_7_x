class LocationTagMap < ActiveRecord::Base
  set_table_name "location_tag_map"
  set_primary_keys :location_tag_id, :location_id
  belongs_to :location_tag
  belongs_to :location
end
