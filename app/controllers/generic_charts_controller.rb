class GenericChartsController < ApplicationController
  def series
    @values =  params[:results] 
    @patient = Patient.find(params[:patient_id])                                
    @patient_bean = PatientService.get_patient(@patient.person)                 
    @test = params[:type]                                     
    render :layout => 'menu'
  end

end
