using PRAS

sys = SystemModel("/Users/tborbath/.julia/dev/ResourceAdq/test/test.pras")
smallsample = SequentialMonteCarlo(samples=10, seed=123)
shortfallresult = assess(sys, Convolution(), Shortfall())
eue, lole = EUE(shortfallresult[1]), LOLE(shortfallresult[1])
