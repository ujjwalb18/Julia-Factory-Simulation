
using DataStructures
using Distributions
using StableRNGs
using Dates
using Printf

# Loading the simulation file
include("factory_simulation.jl")


# Setting the specific Parameters as per the problem statement (Page 24)
seed = 1
mean_interarrival = 60.0
mean_construction_time = 25.0
mean_interbreakdown_time = 2880.0
mean_repair_time = 180.0
T = 1000.0
P = Parameters(seed, mean_interarrival, mean_construction_time, mean_interbreakdown_time, mean_repair_time)

# Creating f=the directory for seed =1
dir = pwd()*"/data/"*"/parameter_1"*"/seed_"*string(seed)
mkpath(dir)

# Creating the files
file_entities = dir*"/entities.csv"
file_state = dir*"/state.csv"

# Now opening the file writer so that we can output the files
fid_entities = open(file_entities, "w")
fid_state = open(file_state, "w")

# Now writing metadata to files
write_metadata(fid_entities)
write_metadata(fid_state)

# Now writing parameter values used for simulation to files 
write_parameters(fid_entities, P)
write_parameters(fid_state, P)

# Now writing the headers into the files
write_entity_header( fid_entities,  Orders_Lawnmowers(0, 0.0) )
print(fid_state,"time,event_id,event_type,length_event_list,length_queue,in_service,machine_status")
println(fid_state)

# Running the simulation using the run command
(state, R) = initialise( P ) 
run!(state, R, T, fid_state, fid_entities)

# Closing the files after the simulation is complete
close(fid_entities)
close(fid_state)
