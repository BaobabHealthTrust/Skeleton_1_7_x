class GenericLocationController < ApplicationController
    def management
      render :layout => "menu"
    end
    
    def new
      @act = 'create'
    end
    
    def search
      @names = search_locations(params[:search_string].to_s, params[:act].to_s)
      render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"           
    end

    def search_locations(search_string, act)
      field_name = "name"
      if act == "delete"  || act == "print" then
          sql = "SELECT *
                 FROM location
                 WHERE location_id IN (SELECT location_id
                              FROM location_tag_map
                              WHERE location_tag_id = (SELECT location_tag_id
	                                   FROM location_tag
	                                   WHERE name = 'Workstation Location'))
                 ORDER BY name ASC"
      elsif act == "create" then
          sql = "SELECT *
                 FROM location
                 WHERE location_id NOT IN (SELECT location_id
                              FROM location_tag_map
                              WHERE location_tag_id = (SELECT location_tag_id
	                                   FROM location_tag
	                                   WHERE name = 'Workstation Location'))  AND name LIKE '%#{search_string}%'
                 ORDER BY name ASC"
      end
      Location.find_by_sql(sql).collect{|name| name.send(field_name)}
  end

    def create
        clinic_name = params[:location_name]
        if Location.find_by_name(clinic_name[:clinic_name]) == nil then
            location = Location.new
            location.name = clinic_name[:clinic_name]
            location.creator  = current_user.id.to_s
            location.date_created  = Time.current.strftime("%Y-%m-%d %H:%M:%S")
            location.save rescue (result = false)

            location_tag_map = LocationTagMap.new
            location_tag_map.location_id = location.id
            location_tag_map.location_tag_id = LocationTag.find_by_name("Workstation location").id
            result = location_tag_map.save rescue (result = false)
            
            if result == true then 
               flash[:notice] = "location #{clinic_name[:clinic_name]} added successfully"
            else
               flash[:notice] = "location #{clinic_name[:clinic_name]} addition failed"
            end  
        else
            location_tag_map = LocationTagMap.new
            location_tag_map.location_id = Location.find_by_name(clinic_name[:clinic_name]).id
            location_tag_map.location_tag_id = LocationTag.find_by_name("Workstation location").id
            result = location_tag_map.save rescue (result = false)
            #raise result.to_s
            if result == true then 
               flash[:notice] = "location #{clinic_name[:clinic_name]} added successfully"
            else
               flash[:notice] = "<span style='color:red; display:block; background-color:#DDDDDD;'>location #{clinic_name[:clinic_name]} addition failed</span>"
            end
        end
        redirect_to "/clinic" and return
    end
    
    def delete
        clinic_name = params[:location_name]
        location_id = Location.find_by_name(clinic_name[:clinic_name]).id rescue -1
        location_tag_id = LocationTag.find_by_name("Workstation location").id rescue -1
        location_tag_map = LocationTagMap.find(location_tag_id, location_id) 
        result = location_tag_map.delete rescue false
        
        if result != false then 
           flash[:notice] = "location #{clinic_name[:clinic_name]} delete successfully"
        else
           flash[:notice] = "<span style='color:red; display:block; background-color:#DDDDDD;'>location #{clinic_name[:clinic_name]} deletion failed</span>"
        end
        redirect_to "/clinic" and return 
    end
    
    def new
      @act = params[:act]
    end

    def print
      location_name = params[:location_name][:clinic_name].to_s
      print_location_and_redirect("/location/location_label?location_name=#{location_name}", "/clinic")
    end

  def get_location_label(location)
    return unless location.location_id
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,5,15,120,false,"#{location.location_id}")
    label.draw_multi_text("#{location.name}")
    label.print(1)
  end
    
	def location_label
		location_name = params[:location_name]
		print_string = get_location_label(Location.find_by_name(location_name))
		send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbl", :disposition => "inline")
    end
end
