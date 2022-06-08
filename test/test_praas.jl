using PRAS 
rts = SystemModel("/Users/tborbath/.julia/dev/ResourceAdq/test/test_inputs/rts.pras")
smallsample = SequentialMonteCarlo(samples=100, seed=10233)
@time x = assess(rts, smallsample, Shortfall());
