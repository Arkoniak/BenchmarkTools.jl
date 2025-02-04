mutable struct Preferences
    benchmark_output::String
    benchmark_histogram::String
end

const PREFS = Preferences("classical", "classical")
const PREFS_FILE_NAME = "benchmarkext.toml"
const ALLOWED = Dict(:benchmark_output => ["classical", "fancy"],
                     :benchmark_histogram => ["classical", "fancy"])

function update!(prefs::Preferences, data)
    for k in fieldnames(Preferences)
        ks = string(k)
        haskey(data, ks) || continue
        setfield!(prefs, k, data[ks])
    end

    return
end

default_prefs_path(default) = joinpath(first(DEPOT_PATH), "prefs", default)

function get_prefs_path(default)
    haskey(ENV, "JULIA_BENCHMARKEXT_CONFIG") && return ENV["JULIA_BENCHMARKEXT_CONFIG"]
    path = default_prefs_path(default)
    isfile(path) && return path

    return ""
end
initialize_prefs(prefs = PREFS, default = PREFS_FILE_NAME) = load_preferences!("", prefs, default)

########################################
# Exported
########################################
"""
    set_preferences!(; kwargs...)

Set preferences for current session. Subset of allowed keywords and their values
can be found in BenchmarkExt.ALLOWED
"""
function set_preferences!(prefs = PREFS; kwargs...)
    for (k, v) in kwargs
        haskey(ALLOWED, k) || (@warn "Unknown settings \"$k\""; continue)
        v in ALLOWED[k] || (@warn "Unsupported value \"$v\" for \"$k\""; continue)

        setfield!(prefs, k, v)
    end

    return nothing
end

"""
    save_preferences!()

Store current preferences so they can to be reused between sessions. Saved 
preferences automatically loaded during `using BenchmarkExt`. Preferences 
saved either in path defined in `JULIA_BENCHMARKEXT_CONFIG` environment 
variable or `~/.julia/prefs/benchmarkext.toml`
"""
function save_preferences!(prefs = PREFS, default = PREFS_FILE_NAME)
    path = get_prefs_path(default)
    if isempty(path)
        path = default_prefs_path(default)
        mkpath(dirname(path))
    end

    data = Dict{Symbol, String}()
    for k in fieldnames(Preferences)
        data[k] = getfield(prefs, k)
    end
    open(path, "w") do io
        TOML.print(io, data)
    end

    return
end

"""
    load_preferences!(path)

Load preferences from the path. If path is an empty string, then default 
path location is used, i.e. path defined in `JULIA_BENCHMARKEXT_CONFIG`
environment variable or `~/.julia/prefs/benchmarkext.toml`
"""
function load_preferences!(path, prefs = PREFS, default = PREFS_FILE_NAME)
    path = isempty(path) ? get_prefs_path(default) : path
    isempty(path) && return
    try
        update!(prefs, TOML.parsefile(path))
    catch err
        @warn "Unable to load BenchmarkExt configuration file in $path " err
    end

    return
end
