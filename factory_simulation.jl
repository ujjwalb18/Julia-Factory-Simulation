#First we make use of the Standard packages we have been using in this course.

using DataStructures
using Distributions
using StableRNGs

# Additional packages
using Dates
using Printf

# Since our Entity is the Lawnmower orders, which arrive in our order queue, we shall create a struct for Lawnmower orders.
mutable struct Orders_Lawnmowers
    id:: Int64
    arrival_time:: Float64
    service_start_time:: Float64
    completion_time:: Float64
    interrupted:: Int64

    # Constructor that takes id and arrival_time as arguments
    function Orders_Lawnmowers(id::Int64, arrival_time::Float64)
        return new(id, arrival_time, 0.0, 0.0, 0)
    end
end

# Now we will be defining the states that our factory system can be in. These states are: order arrival, breakdown, repair and completion.
# Every event contains two attributes: id- which denotes every unique event, time- which denotes the time of that event
abstract type Event end

struct Arrival <: Event
    id:: Int64
    time:: Float64
end

mutable struct Breakdown <: Event
    id:: Int64
    time:: Float64
end

mutable struct Repair <: Event
    id:: Int64
    time:: Float64
end

mutable struct Completion <: Event
    id:: Int64
    time:: Float64
end

# Now creating data structure for passing parameters:
struct Parameters
    seed::Int64
    mean_interarrival::Float64
    mean_construction_time::Float64
    mean_interbreakdown_time::Float64
    mean_repair_time::Float64
end

struct RandomNGs
    rng::StableRNGs.LehmerRNG
    interarrival_time::Function
    construction_time::Function
    interbreakdown_time::Function
    repair_time::Function
end

# Now creating a n initialisation constructor function for RandomNGs to set the random numbers generated. (As defined in the problem statement 20)

function RandomNGs(P::Parameters)

    rng = StableRNG(P.seed)
    interarrival_time() = rand(rng, Exponential(P.mean_interarrival))
    construction_time() = P.mean_construction_time
    interbreakdown_time() = rand(rng, Exponential(P.mean_interbreakdown_time))
    repair_time() = rand(rng, Exponential(P.mean_repair_time))

    return RandomNGs(rng, interarrival_time,  construction_time, interbreakdown_time, repair_time)
end

# Now creating our initialise function as defined in the problem statement page 20)

function initialise( P::Parameters )

    R = RandomNGs( P ) # create the RNGs
    system = Machine_State() # create the initial state structure
    # add an arrival at time 0.0
    t0 = 0.0
    system.n_events += 1 # your system state should keep track of
    # events
    enqueue!( system.event_queue, Arrival(0,t0), t0)
    # add a breakdown at time 150.0
    t1 = 150.0
    system.n_events += 1
    enqueue!( system.event_queue, Breakdown(system.n_events, t1), t1 )
    return (system, R)
end

# Now defining the mutable struct using which we can define the state of our system.
mutable struct Machine_State
    time:: Float64
    n_entities:: Int64
    n_events:: Int64
    event_queue:: PriorityQueue{Event,Float64}
    lawnmower_order_queue:: Queue{Orders_Lawnmowers}
    in_service:: Union{Orders_Lawnmowers,Nothing}
    machine_status:: Int64
end

#  Now creating our State() that returns an initial system State variables with any required queues or lists created, but empty, and the clock time set to 0.0.
function Machine_State()

    init_time = 0.0
    init_n_entities = 0
    init_n_events = 0
    init_event_queue = PriorityQueue{Event,Float64}()
    init_lawnmower_order_queue = Queue{Orders_Lawnmowers}()
    init_in_service = nothing
    init_machine_status = 0

    return Machine_State( init_time, 
                  init_n_entities, 
                  init_n_events, 
                  init_event_queue, 
                  init_lawnmower_order_queue, 
                  init_in_service, 
                  init_machine_status)
end

function move_to_server!(S::Machine_State, R::RandomNGs)
    
    # Move the lawnmower from a queue into construction
    S.in_service = dequeue!(S.lawnmower_order_queue)
    
    # Now starting the service
    S.in_service.service_start_time = S.time

    # Best current guess at service time
    completion_time = S.time + R.construction_time()
    
    # Create a completion event for the lawnmower and then adding it to event queue
    S.n_events += 1
    completion_event = Completion(S.n_events, completion_time) 
    enqueue!(S.event_queue, completion_event, completion_time)
    
    return nothing
end


# Creating update functions that should modify the state S appropriately

# Defining an Invalid event
function update!(S::Machine_State, R::RandomNGs, E::Event)
    throw(DomainError("Invalid event type" ))
end

# Defining the Arrival event
function update!(S::Machine_State, R::RandomNGs, E::Arrival)    

    # Creating a lawnmower order arrival event and then putting it in the front of the queue.
    S.n_entities += 1   # New entity will enter the system
    new_order = Orders_Lawnmowers(S.n_entities, E.time)        
    
    # Now adding the lawnmower order to the appropriate queue
    enqueue!(S.lawnmower_order_queue, new_order)
    
    # Now we will generate the next arrival event and enqueue it
    next_arrival = Arrival(S.n_events, S.time + R.interarrival_time())
    enqueue!(S.event_queue, next_arrival, next_arrival.time)

    # The lawnmower order goes to machine if one is not being built and the machine is operational.
    if (S.in_service === nothing) && (S.machine_status === 0) 
        move_to_server!(S, R)
    end

    return nothing
end

# Defining the Breakdown event
function update!(S::Machine_State, R::RandomNGs, E::Breakdown)
   
    # Updating machine status to broken as breakdown event has taken place.
    S.machine_status = 1

    # Incrementing the number of events
    S.n_events += 1

    # Calculating the time when a repair event will occur after a breakdown event
    E.time = S.time + R.repair_time()
    
    # Now we will trigger a repair event and add it to the event queue
    repair_machine = Repair(S.n_events, E.time)
    enqueue!(S.event_queue, repair_machine, E.time)
	
    # Now we can check if there is a lawnmower under construction. If there is one, we will interrupt the service.
    if S.in_service !==nothing

        S.in_service.interrupted = 1
        
        # for (E, E.time) in S.event_queue
        #     if E.time >= system.time && typeof(event) <: Completion
        #         S.event_queue[E] += repair_time
        #         E.time = repair_time + E.time
        #     end
        # end

        # Now when the machine breaks down, the time of completion of the current lawnmower will be extended (As per problem statement page 18).
        for (E, p) in S.event_queue
            if typeof(E) === Completion
                start_time = S.event_queue[E]
                S.event_queue[E] = start_time + R.repair_time()
            end
        end
    end
end

# Completion Event
function update!(S::Machine_State, R::RandomNGs, E::Completion)
    
    #Extracting all the information for the lawnmower order that got completed.
    completed_lawnmower = deepcopy(S.in_service)
    # simulation_time = S.time

    # Assign the simulation time as completion_time if a lawnmower is finished.
    if completed_lawnmower !== nothing
        completed_lawnmower.completion_time = S.time
    end
        
    # Resetting the machine status to be available. Then checking if lawnmower_order_queue is not empty and the machine is operational
    S.in_service = nothing
    if !isempty(S.lawnmower_order_queue) && (S.machine_status === 0)
        move_to_server!(S, R)
    end 

    return completed_lawnmower 
end

# Repair event
function update!(S::Machine_State, R::RandomNGs, E::Repair)     

    # Update the machine status to working (0 means operational)
    S.machine_status = 0

    # Increment the number of events
    S.n_events += 1

    # Obtaining the breakdown time
    breakdown_time = R.interbreakdown_time()
    
    # Generate and add a future breakdown event to the event queue
    E.time = S.time + breakdown_time

    # Now creating a future breakdown event
    future_breakdown = Breakdown(S.n_events, E.time)
    
    # Enqueing the event
    enqueue!(S.event_queue, future_breakdown, E.time)

    # If the machine is empty and there is a lawnmower in the queue, move it to the server
    if !isempty(S.lawnmower_order_queue) && (S.in_service === nothing)
        move_to_server!(S, R)
    end
end


# Now defining the functions to writeout paramters and cextra metadata (As per problem statement page 21)
function write_parameters(output::IO, P::Parameters)

    T = typeof(P)
    for name in fieldnames(T)
        println(output, "# parameter: $name = $(getfield(P,name))")
    end
end

write_parameters(P::Parameters) = write_parameters(stdout, P)

function write_metadata(output::IO) # function to writeout extra metadata

    (path, prog) = splitdir( @__FILE__ )
    println(output, "# file created by code in $(prog)")
    t = now()
    println(output, "# file created on $(Dates.format(t, "yyyy-mm-dd at HH:MM:SS"))")
end

function write_state(event_file::IO, system::Machine_State, event::Event)

    type_of_event = typeof(event)

    # Store our system service status
    if system.in_service === nothing
        in_service_value = 0
    else
        in_service_value = 1
    end

    # Append "Departed" to the type_of_event if it's a Completion event
    if type_of_event === Completion
        type_of_event = "Departed"
    end

    @printf(event_file,
            "%11.2f, %6d, %12s, %7d, %3d, %3d, %6d",
            system.time,
            event.id,
            type_of_event,
            length(system.event_queue),
            length(system.lawnmower_order_queue),
            in_service_value,
            system.machine_status
        )

    @printf(event_file, "\n")
end


function write_entity_header(entity_file::IO, entity)

    T = typeof( entity )
    x = Array{Any,1}(undef, length( fieldnames(typeof(entity))))
    for (i,name) in enumerate(fieldnames(T))
        tmp = getfield(entity,name)
        if isa(tmp, Array)
            x[i] = join( repeat([name], length(tmp)), ',')
        else
            x[i] = name
        end
    end
    println( entity_file, join(x, ','))
end

function write_entity(entity_file::IO, entity; debug_level::Int = 0)

    T = typeof(entity)
    x = Array{Any, 1}(undef, length(fieldnames(typeof(entity))))
    for (i, name) in enumerate(fieldnames(T))
        tmp = getfield(entity, name)
        if isa(tmp, Array)
            x[i] = join(tmp, ',')
        else
            x[i] = round(tmp, digits=3)
        end
    end

    # Append "Departed" to the entity type
    push!(x, "Departed")

    println(entity_file, join(x, ','))
end

# Now creating the run function to run the main simulation loop for time T
function run!(state::Machine_State, R::RandomNGs, T::Float64, fid_state::IO, fid_entities::IO)

    # Starting the main simulation loop
    while state.time < T
        # Using dequeue to get the next event from the queue
        (event, time) = dequeue_pair!(state.event_queue)
        state.time = time
        state.n_events += 1

        # Writing out event and state data before the event
        write_state(fid_state, state, event)

        # After event update is not required as per the problem statement (Page 21)
        # Fetch the completed order
        completion = update!(state, R, event)

        # Write out entity data if it was a departure from the system (i.e., a completion event)
        if completion !== nothing
            write_entity(fid_entities, completion)
        end
    end

    return state
end
