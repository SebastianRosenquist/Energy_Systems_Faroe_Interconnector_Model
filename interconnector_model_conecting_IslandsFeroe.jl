using JuMP
using Clp
using Plots, StatsPlots
using DataFrames, CSV
using FilePathsBase

########################################################################################################################
# TEST PARAMETERS DEFINITION

# Name of what we are testing (this will be used to create the folder to save the results)
name = "5x wind power on IF, 2x solar and wind DK1 and DK2, 3x Solar and 2x wind UK with 500 mw interconnector between IF and UK"

# Interconnector capacities for testing
IF_DK1_interconnector_capacity = 0  # MW
IF_UK_interconnector_capacity = 500  # MW

# Define the season
# Change this to "winter", "spring", "summer", or "autumn" as needed
season = "autumn"  

# Factors of installed capacity for each node and technology
# These are the installed capacities for each technology in each node
# 2 means 2x the installed capacity
pv_installed_DK1 = 2
wind_installed_DK1 = 2 

pv_installed_DK2 = 2 
wind_installed_DK2 = 2 

pv_installed_IF = 1  
wind_installed_IF = 5  

pv_installed_UK = 3  
wind_installed_UK = 2  


########################################################################################################################
# DATA DEFINITION 

# Read the corresponding data file based on the season
if season == "winter"
    data = CSV.read("data/data_winter.csv", DataFrame)
elseif season == "spring"
    data = CSV.read("data/data_spring.csv", DataFrame)
elseif season == "summer"
    data = CSV.read("data/data_summer.csv", DataFrame)
elseif season == "autumn"
    data = CSV.read("data/data_autumn.csv", DataFrame)
else
    error("Invalid season specified")
end
names(data)
println(data)

# We define the sets and parameters
T = data[!, :hour] 
P = ["p1_Dk1", "p2_Dk1", "pv_Dk1", "wind_Dk1", "p1_Dk2", "p2_Dk2", "pv_Dk2", "wind_Dk2", "p1_IF", "p2_IF", "pv_IF", "wind_IF", "p1_UK", "p2_UK", "pv_UK", "wind_UK"]
DISP = ["p1_Dk1", "p2_Dk1", "p1_Dk2", "p2_Dk2", "p1_IF", "p2_IF", "p1_UK", "p2_UK"]
NONDISP = ["pv_Dk1", "wind_Dk1", "pv_Dk2", "wind_Dk2", "pv_IF", "wind_IF", "pv_UK", "wind_UK"]
N = ["nDk1", "nDk2", "nIF", "nUK"]  # these are the nodes in our model

# We define the demand for each node (in MWh)
demand = Dict(
    "nDk1" => data[!, :demandDk1], 
    "nDk2" => data[!, :demandDk2],
    "nIF" => data[!, :demandIF], 
    "nUK" => data[!, :demandUK]) 
println(demand)

# We define our generators and their marginal costs (in Euro/MWh)
mc = Dict(
    # Coal power plants
    "p1_Dk1" => 150, # Coal price
    "p1_Dk2" => 160,
    "p1_IF" => 200,
    "p1_UK" => 170,
    
    # Oil power plants
    "p2_Dk1" => 45 , # Oil price
    "p2_Dk2" => 55,
    "p2_IF" => 100, 
    "p2_UK" => 65
)

# We define the upper bounds (installed capacity) for the generators (in MW) 
# for each node and technology (p1 = coal, p2 = oil)
# This data is based on the installed capacity data from https://app.electricitymaps.com
g_max = Dict(
    "p1_Dk1" => 1940,
    "p1_Dk2" => 1080,
    "p1_IF" => 0,
    "p1_UK" => 1490,
    
    "p2_Dk1" => 195,
    "p2_Dk2" => 764,
    "p2_IF" => 87,
    "p2_UK" => 37000
)

# We define the feed-in for each node and technology
feedin = Dict(
    ("nDk1", "wind_Dk1") => data[!, :windDk1] .* wind_installed_DK1,
    ("nDk1", "pv_Dk1") => data[!, :pvDk1] .* pv_installed_DK1,
    ("nDk2", "wind_Dk2") => data[!, :windDk2] .* wind_installed_DK2,
    ("nDk2", "pv_Dk2") => data[!, :pvDk2] .* pv_installed_DK2,
    ("nIF", "wind_IF") => data[!, :windIF] .* wind_installed_IF,
    ("nIF", "pv_IF") => data[!, :pvIF] .* pv_installed_IF,
    ("nUK", "wind_UK") => data[!, :windUK] .* wind_installed_UK,
    ("nUK", "pv_UK") => data[!, :pvUK] .* pv_installed_UK
)

# Function to access the feed-in for each node and technology
function res_feed_in(n, res)
    if haskey(feedin, (n, res))
        return feedin[(n, res)]
    else
        return zeros(length(T)) 
    end
end

# We define the grid of our model
n2p = Dict(
    "nDk1" => ["p1_Dk1", "p2_Dk1"],  # Multiple plants in the same node
    "nDk2" => ["p1_Dk2", "p2_Dk2"],  # Multiple plants in the same node
    "nIF" => ["p1_IF", "p2_IF"],  # Multiple plants in the same node
    "nUK" => ["p1_UK", "p2_UK"]   # Multiple plants in the same node
)

# Maps the inverse of n2p as a dict: power plant to node
p2n = Dict(p => k for (k, v) in n2p for p in v)

# Net transfer capacity for each line (the grid limits) in MW (0 means no connection)
ntc = Dict(
    # Internal interconnectors
    ("nDk1", "nDk1") => 0,
    ("nDk2", "nDk2") => 0,
    ("nIF", "nIF") => 0,
    ("nUK", "nUK") => 0,

    # External interconnectors
    # DK1
    ("nDk1", "nDk2") => 600, # DK1-DK2 link
    ("nDk1", "nIF") => IF_DK1_interconnector_capacity,
    ("nDk1", "nUK") => 1400, # Viking link 
    
    # DK2
    ("nDk2", "nDk1") => 600,  # DK2-DK1 link
    ("nDk2", "nIF") => 0,
    ("nDk2", "nUK") => 0,  
    
    # IF
    ("nIF", "nDk1") => IF_DK1_interconnector_capacity, 
    ("nIF", "nDk2") => 0,
    ("nIF", "nUK") => IF_UK_interconnector_capacity,
    
    # UK
    ("nUK", "nDk1") => 1400,  # Viking link
    ("nUK", "nDk2") => 0, 
    ("nUK", "nIF") => IF_UK_interconnector_capacity
)

#######################################################################################################################
# MODEL CREATION 

m = Model(Clp.Optimizer)

@variables m begin
    g_max[disp] >= G[disp=DISP, T] >= 0 # an upper bound can already be assigned here
    CU[N,T] >= 0 #additional dimension of N
    get(ntc, (n,nn), 0) >= FLOW[n=N,nn=N,T] >= 0 # if no ntc exist this variable is fixed to 0
end

# Objective function: Minimizing generation cost
@objective(m, Min, 
    sum(mc[disp] * G[disp, t] for disp in DISP, t in T)  # Generation cost minimization
)

# Constraint for electricity balance at each node
@constraint(m, ElectricityBalance[n in N, t in T], 
    sum(G[disp, t] for disp in n2p[n]) +  # Dispatchable generation in the node
    sum(res_feed_in(n, ndisp)[t] for ndisp in NONDISP) +  # Non-dispatchable generation, correctly accessing feedin
    sum(FLOW[nn, n, t] .- FLOW[n, nn, t] for nn in N) -  # Flows between nodes
    CU[n, t] == demand[n][t]  # Demand coverage at each node
)

optimize!(m)


#########################################################################################################################
#RESULTS 
#This are the results of how much energy the generators are providing
result_G = value.(G)
println(value.(G))

g = DataFrame(
    (variable="dispatchable", node=n, t=t, value=sum(result_G[p, t] for p in n2p[n]))
    for n in N, t in T
)

println(g)

#This are the results of how much energy is being exchanged between nodes
result_FLOW = value.(FLOW)
exchange = DataFrame(
        (variable="exchange",
        node=n,
        t=t,
        value = sum(result_FLOW[nn,n,t] - result_FLOW[n,nn,t] for nn in N))
    for n in N, t in T
)

result_CU = value.(CU)

# This are the results of how much curtailment is happening
curtailment = DataFrame(
        (variable="curtailment",
        node=n,
        t=t,
        value = result_CU[n,t])
    for n in N, t in T
)

# This are the results of how much non-dispatchable energy is being generated
nondispatchable = DataFrame(
        (variable="nondisp",
        node=n,
        t=t,
        value = sum(res_feed_in(n,ndisp)[t] for ndisp=NONDISP))
    for n in N, t in T
)

# Concatenate all results
energybalance = vcat(curtailment, exchange, g, nondispatchable)

price = dual.(ElectricityBalance)


###############################################################################
### Plotting ###

colors = [:brown :red :purple :green]

df_nDk1 = filter(x-> x.node == "nDk1", energybalance)
df_nDk2 = filter(x-> x.node == "nDk2", energybalance)
df_nIF = filter(x-> x.node == "nIF", energybalance)
df_nUK = filter(x-> x.node == "nUK", energybalance)


# Plotting DK1 results
x1 = df_nDk1[:,:t]
y1 = df_nDk1[:,:value]
g1 = df_nDk1[:,:variable]

n1 = groupedbar(x1,y1, group=g1,
    color=colors,
    bar_position=:stack,
    legend=:bottomleft,
    yaxis="MW",
    title="DK1 $season",
    grid=false)

price1 = price["nDk1",:].data
n1_twin = twinx(n1)
scatter!(n1_twin, price1,
    color=:black,
    legend=false,
    ylim=(-10,200),
    grid=false,
    yaxis="Price (Euro/MWh)"
)

# Plotting DK2 results
x2 = df_nDk2[:,:t]
y2 = df_nDk2[:,:value]
g2 = df_nDk2[:,:variable]

n2 = groupedbar(x2,y2, group=g2,
    color=colors,
    bar_position=:stack,
    legend=:bottomleft,
    title="DK2 $season",
    grid=false
)

price2 = price["nDk2",:].data
n2_twin = twinx(n2)
scatter!(n2_twin, price2,
    color=:black,
    legend=false,
    ylim=(-10,200),
    grid=false,
    yaxis="Price (Euro/MWh)"
)

# Plotting IF results
x3 = df_nIF[:,:t]
y3 = df_nIF[:,:value]
g3 = df_nIF[:,:variable]

n3 = groupedbar(x3,y3, group=g3,
    color=colors,
    bar_position=:stack,
    legend=:bottomleft,
    yaxis="MW",
    title="IF $season",
    grid=false
)

price3 = price["nIF",:].data
n3_twin = twinx(n3)
scatter!(n3_twin, price3,
    color=:black,
    legend=false,
    ylim=(-10,200),
    grid=false,
    yaxis="Price (Euro/MWh)"
)

# Plotting UK results
x4 = df_nUK[:,:t]
y4 = df_nUK[:,:value]
g4 = df_nUK[:,:variable]

n4 = groupedbar(x4,y4, group=g4,
    color=colors,
    bar_position=:stack,
    legend=:bottomleft,
    yaxis="MW",
    title="UK $season",
    grid=false,
)

price4 = price["nUK",:].data
n4_twin = twinx(n4)
scatter!(n4_twin, price4,
    color=:black,
    legend=false,
    ylim=(-10,200),
    grid=false,
    yaxis="Price (Euro/MWh)"
)


# Create the folder if it doesn't exist
folder_name = "results/$season/$name"
mkpath(folder_name)

# Save the plots
plot(n1, n2, n3, n4, grid=(4,1), legend = false)
savefig(joinpath(folder_name, "result_ALL-transport_$season.pdf"))
plot(n1, grid=(1,1))
savefig(joinpath(folder_name, "result_Dk1_transport_$season.pdf"))
plot(n2, grid=(1,1))
savefig(joinpath(folder_name, "result_Dk2_transport_$season.pdf"))
plot(n3, grid=(1,1))
savefig(joinpath(folder_name, "result_IF_transport_$season.pdf"))
plot(n4, grid=(1,1))
savefig(joinpath(folder_name, "result_UK_transport_$season.pdf"))
