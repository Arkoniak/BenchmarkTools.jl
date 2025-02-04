module GroupsTests

using BenchmarkExt
using BenchmarkExt: TrialEstimate, Parameters
using ReTest

seteq(a, b) = length(a) == length(b) == length(intersect(a, b))

function setup_vals()
    g1 = BenchmarkGroup(["1", "2"])

    t1a = TrialEstimate(Parameters(time_tolerance = .05, memory_tolerance = .05), 32, 1, 2, 3)
    t1b = TrialEstimate(Parameters(time_tolerance = .40, memory_tolerance = .40), 4123, 123, 43, 9)
    tc = TrialEstimate(Parameters(time_tolerance = 1.0, memory_tolerance = 1.0), 1, 1, 1, 1)

    g1["a"] = t1a
    g1["b"] = t1b
    g1["c"] = tc

    g1copy = copy(g1)
    g1similar = similar(g1)

    g2 = BenchmarkGroup(["2", "3"])

    t2a = TrialEstimate(Parameters(time_tolerance = .05, memory_tolerance = .05), 323, 1, 2, 3)
    t2b = TrialEstimate(Parameters(time_tolerance = .40, memory_tolerance = .40), 1002, 123, 43, 9)

    g2["a"] = t2a
    g2["b"] = t2b
    g2["c"] = tc

    trial = BenchmarkExt.Trial(Parameters(), [1, 2, 5], [0, 1, 1], [3, 4, 5], [56, 58, 62])

    gtrial = BenchmarkGroup([], Dict("t" => trial))

    (g1, g1copy, g1similar, g2, gtrial, t1a, t1b, tc, t2a, t2b)
end

function setup_extra(g1, g2, gtrial)
    groupsa = BenchmarkGroup()
    groupsa["g1"] = g1
    groupsa["g2"] = g2
    g3a = addgroup!(groupsa, "g3", ["3", "4"])
    g3a["c"] = TrialEstimate(Parameters(time_tolerance = .05, memory_tolerance = .05), 6341, 23, 41, 536)
    g3a["d"] = TrialEstimate(Parameters(time_tolerance = .13, memory_tolerance = .13), 12341, 3013, 2, 150)

    groups_copy = copy(groupsa)
    groups_similar = similar(groupsa)

    groupsb = BenchmarkGroup()
    groupsb["g1"] = g1
    groupsb["g2"] = g2
    g3b = addgroup!(groupsb, "g3", ["3", "4"])
    g3b["c"] = TrialEstimate(Parameters(time_tolerance = .05, memory_tolerance = .05), 1003, 23, 41, 536)
    g3b["d"] = TrialEstimate(Parameters(time_tolerance = .23, memory_tolerance = .23), 25341, 3013, 2, 150)

    groupstrial = BenchmarkGroup()
    groupstrial["g"] = gtrial

    (groupsa, g3a, groupsb, g3b, groupstrial, groups_copy, groups_similar)
end

struct Bar end
@testset "BenchmarkGroup" begin
    g1, g1copy, g1similar, g2, gtrial, t1a, t1b, tc, t2a, t2b = setup_vals()

    @test BenchmarkGroup() == BenchmarkGroup([], Dict())
    @test length(g1) == 3
    @test g1["a"] == t1a
    @test g1["b"] == t1b
    @test g1["c"] == tc
    @test haskey(g1, "a")
    @test !(haskey(g1, "x"))
    @test seteq(keys(g1), ["a", "b", "c"])
    @test seteq(values(g1), [t1a, t1b, tc])
    @test iterate(g1) == iterate(g1.data)
    @test iterate(g1, 1) == iterate(g1.data, 1)
    @test seteq([x for x in g1], Pair["a"=>t1a, "b"=>t1b, "c"=>tc])

    @test g1 == g1copy
    @test seteq(keys(delete!(g1copy, "a")), ["b", "c"])
    @test isempty(delete!(delete!(g1copy, "b"), "c"))
    @test isempty(g1similar)
    @test g1similar.tags == g1.tags

    @test time(g1).data == Dict("a" => time(t1a), "b" => time(t1b), "c" => time(tc))
    @test gctime(g1).data == Dict("a" => gctime(t1a), "b" => gctime(t1b), "c" => gctime(tc))
    @test memory(g1).data == Dict("a" => memory(t1a), "b" => memory(t1b), "c" => memory(tc))
    @test allocs(g1).data == Dict("a" => allocs(t1a), "b" => allocs(t1b), "c" => allocs(tc))
    @test params(g1).data == Dict("a" => params(t1a), "b" => params(t1b), "c" => params(tc))

    @test max(g1, g2).data == Dict("a" => t2a, "b" => t1b, "c" => tc)
    @test min(g1, g2).data == Dict("a" => t1a, "b" => t2b, "c" => tc)
    @test ratio(g1, g2).data == Dict("a" => ratio(t1a, t2a), "b" => ratio(t1b, t2b), "c" => ratio(tc, tc))
    @test (judge(g1, g2; time_tolerance = 0.1, memory_tolerance = 0.1).data ==
           Dict("a" => judge(t1a, t2a; time_tolerance = 0.1, memory_tolerance = 0.1),
                "b" => judge(t1b, t2b; time_tolerance = 0.1, memory_tolerance = 0.1),
                "c" => judge(tc, tc; time_tolerance = 0.1, memory_tolerance = 0.1)))
    @test (judge(ratio(g1, g2); time_tolerance = 0.1, memory_tolerance = 0.1) ==
           judge(g1, g2; time_tolerance = 0.1, memory_tolerance = 0.1))
    @test ratio(g1, g2) == ratio(judge(g1, g2))

    @test isinvariant(judge(g1, g1))
    @test isinvariant(time, judge(g1, g1))
    @test isinvariant(memory, judge(g1, g1))
    @test !(isregression(judge(g1, g1)))
    @test !(isregression(time, judge(g1, g1)))
    @test !(isregression(memory, judge(g1, g1)))
    @test !(isimprovement(judge(g1, g1)))
    @test !(isimprovement(time, judge(g1, g1)))
    @test !(isimprovement(memory, judge(g1, g1)))

    @test BenchmarkExt.invariants(judge(g1, g2)).data == Dict("c" => judge(tc, tc))
    @test BenchmarkExt.invariants(time, (judge(g1, g2))).data == Dict("c" => judge(tc, tc))
    @test BenchmarkExt.invariants(memory, (judge(g1, g2))).data == Dict("a" => judge(t1a, t2a), "b" => judge(t1b, t2b), "c" => judge(tc, tc))
    @test BenchmarkExt.regressions(judge(g1, g2)).data == Dict("b" => judge(t1b, t2b))
    @test BenchmarkExt.regressions(time, (judge(g1, g2))).data == Dict("b" => judge(t1b, t2b))
    @test BenchmarkExt.regressions(memory, (judge(g1, g2))).data == Dict()
    @test BenchmarkExt.improvements(judge(g1, g2)).data == Dict("a" => judge(t1a, t2a))
    @test BenchmarkExt.improvements(time, (judge(g1, g2))).data == Dict("a" => judge(t1a, t2a))
    @test BenchmarkExt.improvements(memory, (judge(g1, g2))).data == Dict()

    @test isinvariant(judge(g1, g1))
    @test !(isinvariant(judge(g1, g2)))
    @test isregression(judge(g1, g2))
    @test !(isregression(judge(g1, g1)))
    @test isimprovement(judge(g1, g2))
    @test !(isimprovement(judge(g1, g1)))
    @test invariants(judge(g1, g2)).data == Dict("c" => judge(tc, tc))
    @test regressions(judge(g1, g2)).data == Dict("b" => judge(t1b, t2b))
    @test improvements(judge(g1, g2)).data == Dict("a" => judge(t1a, t2a))

    @testset "struct Bar" begin
        @test BenchmarkExt.invariants(Bar()) == Bar()
        @test BenchmarkExt.invariants(time, (Bar())) == Bar()
        @test BenchmarkExt.invariants(memory, (Bar())) == Bar()
        @test BenchmarkExt.regressions(Bar()) == Bar()
        @test BenchmarkExt.regressions(time, (Bar())) == Bar()
        @test BenchmarkExt.regressions(memory, (Bar())) == Bar()
        @test BenchmarkExt.improvements(Bar()) == Bar()
        @test BenchmarkExt.improvements(time, (Bar())) == Bar()
        @test BenchmarkExt.improvements(memory, (Bar())) == Bar()
    end

    @test minimum(gtrial)["t"] == minimum(gtrial["t"])
    @test median(gtrial)["t"] == median(gtrial["t"])
    @test mean(gtrial)["t"] == mean(gtrial["t"])
    @test maximum(gtrial)["t"] == maximum(gtrial["t"])
    @test params(gtrial)["t"] == params(gtrial["t"])
end

@testset "BenchmarkGroups of BenchmarkGroups" begin
    g1, g1copy, g1similar, g2, gtrial, t1a, t1b, tc, t2a, t2b = setup_vals()
    groupsa, g3a, groupsb, g3b, groupstrial, groups_copy, groups_similar = setup_extra(g1, g2, gtrial)

    @test time(groupsa).data == Dict("g1" => time(g1), "g2" => time(g2), "g3" => time(g3a))
    @test gctime(groupsa).data == Dict("g1" => gctime(g1), "g2" => gctime(g2), "g3" => gctime(g3a))
    @test memory(groupsa).data == Dict("g1" => memory(g1), "g2" => memory(g2), "g3" => memory(g3a))
    @test allocs(groupsa).data == Dict("g1" => allocs(g1), "g2" => allocs(g2), "g3" => allocs(g3a))
    @test params(groupsa).data == Dict("g1" => params(g1), "g2" => params(g2), "g3" => params(g3a))

    for (k, v) in BenchmarkExt.leaves(groupsa)
        @test groupsa[k] == v
    end

    @test max(groupsa, groupsb).data == Dict("g1" => max(g1, g1), "g2" => max(g2, g2), "g3" => max(g3a, g3b))
    @test min(groupsa, groupsb).data == Dict("g1" => min(g1, g1), "g2" => min(g2, g2), "g3" => min(g3a, g3b))
    @test ratio(groupsa, groupsb).data == Dict("g1" => ratio(g1, g1), "g2" => ratio(g2, g2), "g3" => ratio(g3a, g3b))
    @test (judge(groupsa, groupsb; time_tolerance = 0.1, memory_tolerance = 0.1).data ==
           Dict("g1" => judge(g1, g1; time_tolerance = 0.1, memory_tolerance = 0.1),
                "g2" => judge(g2, g2; time_tolerance = 0.1, memory_tolerance = 0.1),
                "g3" => judge(g3a, g3b; time_tolerance = 0.1, memory_tolerance = 0.1)))
    @test (judge(ratio(groupsa, groupsb); time_tolerance = 0.1, memory_tolerance = 0.1) ==
           judge(groupsa, groupsb; time_tolerance = 0.1, memory_tolerance = 0.1))
    @test ratio(groupsa, groupsb) == ratio(judge(groupsa, groupsb))

    @test isinvariant(judge(groupsa, groupsa))
    @test !(isinvariant(judge(groupsa, groupsb)))
    @test isregression(judge(groupsa, groupsb))
    @test !(isregression(judge(groupsa, groupsa)))
    @test isimprovement(judge(groupsa, groupsb))
    @test !(isimprovement(judge(groupsa, groupsa)))
    @test invariants(judge(groupsa, groupsb)).data == Dict("g1" => judge(g1, g1), "g2" => judge(g2, g2))
    @test regressions(judge(groupsa, groupsb)).data == Dict("g3" => regressions(judge(g3a, g3b)))
    @test improvements(judge(groupsa, groupsb)).data == Dict("g3" => improvements(judge(g3a, g3b)))

    @test minimum(groupstrial)["g"]["t"] == minimum(groupstrial["g"]["t"])
    @test maximum(groupstrial)["g"]["t"] == maximum(groupstrial["g"]["t"])
    @test median(groupstrial)["g"]["t"] == median(groupstrial["g"]["t"])
    @test mean(groupstrial)["g"]["t"] == mean(groupstrial["g"]["t"])
    @test params(groupstrial)["g"]["t"] == params(groupstrial["g"]["t"])

end

@testset "Tagging" begin
    g1, g1copy, g1similar, g2, gtrial, t1a, t1b, tc, t2a, t2b = setup_vals()
    groupsa, g3a, groupsb, g3b, groupstrial, groups_copy, groups_similar = setup_extra(g1, g2, gtrial)

    @test groupsa[@tagged "1"] == BenchmarkGroup([], "g1" => g1)
    @test groupsa[@tagged "2"] == BenchmarkGroup([], "g1" => g1, "g2" => g2)
    @test groupsa[@tagged "3"] == BenchmarkGroup([], "g2" => g2, "g3" => g3a)
    @test groupsa[@tagged "4"] == BenchmarkGroup([], "g3" => g3a)
    @test groupsa[@tagged "3" && "4"] == groupsa[@tagged "4"]
    @test groupsa[@tagged ALL && !("2")] == groupsa[@tagged !("2")]
    @test groupsa[@tagged "1" || "4"] == BenchmarkGroup([], "g1" => g1, "g3" => g3a)
    @test groupsa[@tagged ("1" || "4") && !("2")] == groupsa[@tagged "4"]
    @test groupsa[@tagged !("1" || "4") && "2"] == BenchmarkGroup([], "g2" => g2)
    @test groupsa[@tagged ALL] == groupsa
    @test groupsa[@tagged !("1" || "3") && !("4")] == similar(groupsa)

    gnest = BenchmarkGroup(["1"],
                           "2" => BenchmarkGroup(["3"], 1 => 1),
                           4 => BenchmarkGroup(["3"], 5 => 6),
                           7 => 8,
                           "a" => BenchmarkGroup(["3"], "a" => :a, (11, "b") => :b),
                           9 => BenchmarkGroup(["2"],
                                               10 => BenchmarkGroup(["3"]),
                                               11 => BenchmarkGroup()))

    @test sort(leaves(gnest), by=string) ==
    Any[(Any["2",1],1), (Any["a","a"],:a), (Any["a",(11,"b")],:b), (Any[4,5],6), (Any[7],8)]

    @test gnest[@tagged 11 || 10] == BenchmarkGroup(["1"],
                                                    "a" => BenchmarkGroup(["3"],
                                                                          (11, "b") => :b),
                                                    9 => gnest[9])

    @test gnest[@tagged "3"] == BenchmarkGroup(["1"], "2" => gnest["2"], 4 => gnest[4], "a" => gnest["a"],
                                               9 => BenchmarkGroup(["2"], 10 => BenchmarkGroup(["3"])))

    @test gnest[@tagged "1" && "2" && "3"] == BenchmarkGroup(["1"], "2" => gnest["2"],
                                                             9 => BenchmarkGroup(["2"], 10 => BenchmarkGroup(["3"])))

    k = 3 + im
    gnest = BenchmarkGroup(["1"], :hi => BenchmarkGroup([], 1 => 1, k => BenchmarkGroup(["3"], 1 => 1)), 2 => 1)

    @test gnest[@tagged "1"] == gnest
    @test gnest[@tagged "1" && !(:hi)] == BenchmarkGroup(["1"], 2 => 1)
    @test gnest[@tagged :hi && !("3")] == BenchmarkGroup(["1"], :hi => BenchmarkGroup([], 1 => 1))
    @test gnest[@tagged k] == BenchmarkGroup(["1"], :hi => BenchmarkGroup([], k => BenchmarkGroup(["3"], 1 => 1)))
end

@testset "Indexing by BenchmarkGroup" begin
    g = BenchmarkGroup()
    d = Dict("1" => 1, "2" => 2, "3" => 3)
    g["a"] = BenchmarkGroup([], copy(d))
    g["b"] = BenchmarkGroup([], copy(d))
    g["c"] = BenchmarkGroup([], copy(d))
    g["d"] = BenchmarkGroup([], copy(d))
    g["e"] = BenchmarkGroup([], "1" => BenchmarkGroup([], copy(d)),
                            "2" => BenchmarkGroup([], copy(d)),
                            "3" => BenchmarkGroup([], copy(d)))

    x = BenchmarkGroup()
    x["a"] = BenchmarkGroup([], "1" => '1', "3" => '3')
    x["c"] = BenchmarkGroup([], "2" => '2')
    x["d"] = BenchmarkGroup([], "1" => '1', "2" => '2', "3" => '3')
    x["e"] = BenchmarkGroup([], "1" => x["a"], "3" => x["c"])

    gx = BenchmarkGroup()
    gx["a"] = BenchmarkGroup([], "1" => 1, "3" => 3)
    gx["c"] = BenchmarkGroup([], "2" => 2)
    gx["d"] = BenchmarkGroup([], "1" => 1, "2" => 2, "3" => 3)
    gx["e"] = BenchmarkGroup([], "1" => g["e"]["1"][x["a"]], "3" => g["e"]["3"][x["c"]])

    @test g[x] == gx
end

@testset "Indexing by vector" begin
    g1 = BenchmarkGroup(1 => BenchmarkGroup("a" => BenchmarkGroup()))
    g1[[1, "a", :b]] = "hello"
    @test g1[[1, "a", :b]] == "hello"

    g2 = BenchmarkGroup()
    g2[[1, "a", :b]] = "hello"  # should create higher levels on the fly
    @test g2[[1, "a", :b]] == "hello"

    @test g1 == g2

    @testset "benchmarkset" begin
        g1 = @benchmarkset "test set" begin
            @case "test case 1" 1 + 1
            @case "test case 2" 2 + 2
        end

        @test haskey(g1, "test set")
        @test haskey(g1["test set"], "test case 1")
        @test haskey(g1["test set"], "test case 2")
    end
end

@testset "Pretty printing" begin
    g1, g1copy, g1similar, g2, gtrial, t1a, t1b, tc, t2a, t2b = setup_vals()

    g1 = BenchmarkGroup(["1", "2"])
    g1["a"] = t1a
    g1["b"] = t1b
    g1["c"] = tc

    data = read(joinpath(@__DIR__, "data", "test03_pretty.txt"), String)
    pp = strip.(split(data, "\n\n"))

    @test sprint(show, g1) == pp[1]
    @test sprint(show, g1; context = :boundto => 1) == pp[2]
    @test sprint(show, g1; context = :limit => false) == pp[3]
    @test @test_deprecated(sprint(show, g1; context = :limit => 1)) == pp[4]
end

end # module
