class GenericDrugController < ApplicationController

  def name
    @names = Drug.find(:all,:conditions =>["name LIKE ?","%" + params[:search_string] + "%"]).collect{|drug| drug.name}
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

  def delivery
    @drugs = Drug.find(:all).map{|d|d.name}.compact.sort rescue []
  end

  def create_stock
    obs = params[:observations]
    delivery_date = obs[0]['value_datetime']
    expiry_date = obs[1]['value_datetime']
    drug_id = Drug.find_by_name(params[:drug_name]).id
    number_of_tins = params[:number_of_tins].to_f
    number_of_pills_per_tin = params[:number_of_pills_per_tin].to_f
    number_of_pills = (number_of_tins * number_of_pills_per_tin)
    barcode = params[:identifier]
    Pharmacy.new_delivery(drug_id,number_of_pills,delivery_date,nil,expiry_date,barcode)
    #add a notice
    #flash[:notice] = "#{params[:drug_name]} successfully entered"
    redirect_to "/clinic"   # /management"
  end

  def edit_stock
    if request.method == :post
      obs = params[:observations]
      edit_reason = obs[0]['value_coded_or_text']
      encounter_datetime = obs[1]['value_datetime']
      drug_id = Drug.find_by_name(params[:drug_name]).id
      pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
      date = encounter_datetime || Date.today 

      if edit_reason == 'Receipts'
        expiry_date = obs[2]['value_datetime'].to_date
        Pharmacy.new_delivery(drug_id,pills,date,nil,expiry_date,edit_reason)
      else
        Pharmacy.drug_dispensed_stock_adjustment(drug_id,pills,date,edit_reason)
      end
      #flash[:notice] = "#{params[:drug_name]} successfully edited"
      redirect_to "/clinic"   # /management"
    end
  end

  def verification
    obs = params[:observations]
    edit_reason = obs[0]['value_coded_or_text']
    encounter_datetime = obs[0]['value_datetime']
    drug_id = Drug.find_by_name(params[:drug_name]).id
    pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
    date = encounter_datetime || Date.today
    Pharmacy.verified_stock(drug_id,date,pills) 
    redirect_to "/clinic"   # /management"
  end

  def stock_report
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    
    #TODO
#need to redo the SQL query
    encounter_type = PharmacyEncounterType.find_by_name("New deliveries").id
    new_deliveries = Pharmacy.active.find(:all,
      :conditions =>["pharmacy_encounter_type=?",encounter_type],
      :order => "encounter_date DESC,date_created DESC")
    
    current_stock = {}
    new_deliveries.each{|delivery|
      current_stock[delivery.drug_id] = delivery if current_stock[delivery.drug_id].blank?
    }

    @stock = {}
    current_stock.each{|delivery_id , delivery|
      first_date = Pharmacy.active.find(:first,:conditions =>["drug_id =?",
                   delivery.drug_id],:order => "encounter_date").encounter_date.to_date rescue nil
      next if first_date.blank?
      next if first_date > @end_date

      start_date = @start_date
      end_date = @end_date
                   
      drug = Drug.find(delivery.drug_id)
      drug_name = drug.name
      @stock[drug_name] = {"confirmed_closing" => 0,"dispensed" => 0,"current_stock" => 0 ,
        "confirmed_opening" => 0, "start_date" => start_date , "end_date" => end_date,
        "relocated" => 0, "receipts" => 0,"expected" => 0}
      @stock[drug_name]["dispensed"] = Pharmacy.dispensed_drugs_since(drug.id,start_date,end_date)
      @stock[drug_name]["confirmed_opening"] = Pharmacy.verify_stock_count(drug.id,start_date,start_date)
      @stock[drug_name]["confirmed_closing"] = Pharmacy.verify_stock_count(drug.id,start_date,end_date)
      @stock[drug_name]["current_stock"] = Pharmacy.current_stock_as_from(drug.id,start_date,end_date)
      @stock[drug_name]["relocated"] = Pharmacy.relocated(drug.id,start_date,end_date)
      @stock[drug_name]["receipts"] = Pharmacy.receipts(drug.id,start_date,end_date)
      @stock[drug_name]["expected"] = Pharmacy.expected(drug.id,start_date,end_date)
    }    

  end

  def date_select
    @goto = params[:goto]
    @goto = 'stock_report' if @goto.blank?
  end

  def print_barcode
    if request.post?
      print_and_redirect("/drug/print?drug_id=#{params[:drug_id]}&quantity=#{params[:pill_count]}", "/drug/print_barcode")
    else
      @drugs = Drug.find(:all,:conditions =>["name IS NOT NULL"])
    end
  end
  
  def print
      pill_count = params[:quantity]
      drug = Drug.find(params[:drug_id])
      drug_name = drug.name
      drug_name1=""
      drug_name2=""
      drug_quantity = pill_count
      drug_barcode = "#{drug.id}-#{drug_quantity}"
      drug_string_length =drug_name.length

      if drug_name.length > 27
        drug_name1 = drug_name[0..25]
        drug_name2 = drug_name[26..-1]
      end

      if drug_string_length <= 27
        label = ZebraPrinter::StandardLabel.new
        label.draw_text("#{drug_name}", 40, 30, 0, 2, 2, 2, false)
        label.draw_text("Quantity: #{drug_quantity}", 40, 80, 0, 2, 2, 2,false)
        label.draw_barcode(40, 130, 0, 1, 5, 15, 120,true, "#{drug_barcode}")
      else
        label = ZebraPrinter::StandardLabel.new
        label.draw_text("#{drug_name1}", 40, 30, 0, 2, 2, 2, false)
        label.draw_text("#{drug_name2}", 40, 80, 0, 2, 2, 2, false)
        label.draw_text("Quantity: #{drug_quantity}", 40, 130, 0, 2, 2, 2,false)
        label.draw_barcode(40, 180, 0, 1, 5, 15, 100,true, "#{drug_barcode}")
      end
      send_data(label.print(1),:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{drug_barcode}.lbl", :disposition => "inline")
  end

  def expiring
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @expiring_drugs = Pharmacy.expiring_drugs(@start_date,@end_date)
    render :layout => "menu"
  end
  
  def removed_from_shelves
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @drugs_removed = Pharmacy.removed_from_shelves(@start_date,@end_date)
    render :layout => "menu"
  end

  def available_name    
    ids = Pharmacy.active.find(:all).collect{|p|p.drug_id} rescue []
    @names = Drug.find(:all,:conditions =>["name LIKE ? AND drug_id IN (?)","%" + 
          params[:search_string] + "%", ids]).collect{|drug| drug.name}
    render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"
  end

end
