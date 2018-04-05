# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class Import8760LoadProfilePlantHWCHW < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "Import_8760_LoadProfilePlant_HW_CHW"
  end

  # human readable description
  def description
    return "This measure imports 8760 chilled water and hot water demand profiles for use in the LoadProfilePlant. The source is a csv file with seven columns titles: timestep, chw_supply_temp_f, chw_flow_fraction, chw_load_w, hw_supply_temp_f, hw_flow_fraction, hw_load_w."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure imports 8760 chilled water and hot water demand profiles for use in the LoadProfilePlant. The source is a csv file with seven columns titles: timestep, chw_supply_temp_f, chw_flow_frac, chw_load_w, hw_supply_temp_f, hw_flow_frac, hw_load_w."
  end

   # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the name of the space to add to the model
    file_name = OpenStudio::Measure::OSArgument.makeStringArgument("file_name", true)
    file_name.setDisplayName("File Name")
    file_name.setDescription("This is the name of the file containing the schedules to be loaded.")
    args << file_name

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

		require 'csv'

		if !runner.validateUserArguments(arguments(model), user_arguments)
		  return false
		end
	#
	#    # assign the user inputs to variables
		file_name = runner.getStringArgumentValue("file_name", user_arguments)
	#
	#    # check the file_name for reasonableness
		if file_name.empty?
		  runner.registerError("Empty file name was entered.")
		  return false
		end
		
		def create_schedule_and_rename(timeseries, name, model)
		  schedule = OpenStudio::Model::ScheduleInterval::fromTimeSeries(timeseries, model)
		  if schedule.empty?
			puts "Could not create schedule '#{name}'. Skipping"
			return false
		  else
			schedule = schedule.get
			schedule.setName(name)
			return schedule
		  end
		end

		# Loading csv. In my case I have 4 columns timestamp, supply temp, supply flow, load
		raw_data =  CSV.table("/Users/USDF01219/OpenStudio/Measures/import_8760_load_profile_plant_hwchw/#{file_name}") #IT.csv

		# Create Vectors to load the 8760 values.
		chw_supply_temp_c = OpenStudio::Vector.new(8760)
		chw_flow_fraction = OpenStudio::Vector.new(8760)
		chw_load_w = OpenStudio::Vector.new(8760)

		hw_supply_temp_c = OpenStudio::Vector.new(8760)
		hw_flow_fraction = OpenStudio::Vector.new(8760)
		hw_load_w = OpenStudio::Vector.new(8760)


		# Loop on each row of the csv and load data in the OpenStudio::Vector objects
		raw_data.each_with_index do |row, i|
		  # Convert F to C on the fly
		  chw_supply_temp_c[i] = OpenStudio::convert(row[:chw_supply_temp_f],'F','C').get
		  hw_supply_temp_c[i] = OpenStudio::convert(row[:hw_supply_temp_f],'F','C').get
		  # This is a fraction, no conversion needed
		  chw_flow_fraction[i] = row[:chw_flow_fraction]
		  hw_flow_fraction[i] = row[:hw_flow_fraction]
		  # Load is already in Watts
		  chw_load_w[i] = row[:chw_load_w]
		  hw_load_w[i] = row[:hw_load_w]
		end

		# Get number of initial Schedule:FixedInterval for reporting
		initial_number = model.getScheduleFixedIntervals.size

		# To create timeSeries we need a start date (January 1st) and a time interval (hourly interval)
		date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new("Jan"), 1, 2009)
		time = OpenStudio::Time.new(0,1,0,0)

		# Create a timeSeries
		chw_supply_temp_timeSeries = OpenStudio::TimeSeries.new(date, time, chw_supply_temp_c, "C")
		# Convert to schedule and if it worked, rename. See function above
		chw_supply_temp_sch = create_schedule_and_rename(chw_supply_temp_timeSeries, "ChW Supply Outlet Temp Schedule", model)
		hw_supply_temp_timeSeries = OpenStudio::TimeSeries.new(date, time, hw_supply_temp_c, "C")
		hw_supply_temp_sch = create_schedule_and_rename(hw_supply_temp_timeSeries, "HW Supply Outlet Temp Schedule", model)
		
		chw_flow_fraction_timeSeries = OpenStudio::TimeSeries.new(date, time, chw_flow_fraction, "Fraction")
		chw_flow_fraction_sch = create_schedule_and_rename(chw_flow_fraction_timeSeries, "ChW Load Profile - Flow Fraction Schedule", model)
		hw_flow_fraction_timeSeries = OpenStudio::TimeSeries.new(date, time, hw_flow_fraction, "Fraction")
		hw_flow_fraction_sch = create_schedule_and_rename(hw_flow_fraction_timeSeries, "HW Load Profile - Flow Fraction Schedule", model)
				
		chw_load_timeSeries = OpenStudio::TimeSeries.new(date, time, chw_load_w, "W")
		chw_load_sch = create_schedule_and_rename(chw_load_timeSeries, "ChW Load Profile - Load Schedule (Watts)", model)
		hw_load_timeSeries = OpenStudio::TimeSeries.new(date, time, hw_load_w, "W")
		hw_load_sch = create_schedule_and_rename(hw_load_timeSeries, "HW Load Profile - Load Schedule (Watts)", model)

		# Final Reporting
		final_number = model.getScheduleFixedIntervals.size
		puts "Model started with #{initial_number} Schedule:FixedInterval and ended with #{final_number}"

		# to save:
		# model.save(path, true)
		
    return true

  end
  
end

# register the measure to be used by the application
Import8760LoadProfilePlantHWCHW.new.registerWithApplication
