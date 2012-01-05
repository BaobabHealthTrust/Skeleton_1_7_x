class RoleRole < ActiveRecord::Base
  set_table_name :role_role
  set_primary_keys :parent_role, :child_role
  include Openmrs
end
